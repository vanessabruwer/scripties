<#

.DESCRIPTION
Extract ASC Secure Score information from all subscriptions on a regular basis, and write back to a custom table in Azure Monitor Logs

Prerequisite: 
- an Azure Automation account with an Azure Run As account credential.
- Access to the read the Secure Score information for each subscription

.PARAMETER omsWorkspaceId
A Log Analytics Workspace ID.

.PARAMETER omsSharedKey
A Log Analytics Shared Key.

#>

Param(
 [string]$omsWorkspaceId,
 [string]$omsSharedKey
)

$omsWorkspaceId = Get-AutomationVariable -Name 'LAWorkspaceId'
$omsSharedKey = Get-AutomationVariable -Name 'LASharedKey'


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName        
 
    "Logging in to Azure..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint   $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$LogType = "SecureScore"
 
 
# Create the function to create the authorization signature
Function Build-Signature ($omsWorkspaceId, $omsSharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
 
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($omsSharedKey)
 
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $omsWorkspaceId,$encodedHash
    return $authorization
}
 
# Create the function to create and post the request
Function Post-OMSData($omsWorkspaceId, $omsSharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -omsWorkspaceId $omsWorkspaceId `
        -omsSharedKey $omsSharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -fileName $fileName `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $omsWorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
 
    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
    }
 
    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}



# Credit: s_lapointe  https://gallery.technet.microsoft.com/scriptcenter/Easily-obtain-AccessToken-3ba6e593
function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'
  
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
 
# Secure Score is exposed in REST API
function Get-SecureScore($SubscriptionId) 
{
    $token = Get-AzCachedAccessToken
    $authHeader = @{
    'Content-Type'='application\json'
    'Authorization'="Bearer $token"
    }
 
    $result = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Security/secureScores?api-version=2020-01-01-preview" -Method Get -Headers $authHeader
    return $result.value
}

$Subscriptions = Get-AzSubscription

# for each subscription get the quota data
foreach ($Subscription in $Subscriptions)
{
$SubscriptionId = $Subscription.Id
$SubscriptionName = $Subscription.Name


Set-AzContext -SubscriptionId $SubscriptionId
$azureContext = Get-AzContext
$SubscriptionName = $azureContext.Subscription.Name

$json = ''

# Get Secure Score
{
    $SecureScores = Get-SecureScore -SubscriptionId $SubscriptionId
    foreach ($SecureScore in $SecureScores)
    {

         $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "ResourceID":"$($SecureScore.id)", "Name":"$($SecureScore.name)", "DisplayName":"$($SecureScore.properties.displayName)","CurrentScore":"$($SecureScore.properties.score.current)","MaxScore":"$($SecureScore.properties.score.max)","Type":"$($SecureScore.type)"  },
"@
    }
 
}

# Wrap in an array
$json = "[$json]"
write-output $json
 
# Submit the data to the API endpoint
Post-OMSData -omsWorkspaceId $omsWorkspaceId -omsSharedKey $omsSharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
}
