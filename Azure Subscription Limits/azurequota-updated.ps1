<#
.SYNOPSIS
Update Azure PowerShell modules in an Azure Automation account.

.DESCRIPTION
Azure Resource Quotas into a Log Analytics Workspace (Using PowerShell)
Credit to Original Solution: https://blogs.msdn.microsoft.com/tomholl/2017/06/11/get-alerts-as-you-approach-your-azure-resource-quotas/

Prerequisite: an Azure Automation account with an Azure Run As account credential.

.PARAMETER omsWorkspaceId
A Log Analytics Workspace ID.

.PARAMETER omsSharedKey
A Log Analytics Shared Key.

.PARAMETER Subscriptions
A list of subscriptions to gather quota information on. This is formatted ["SubscriptionID1", "SubscriptionID2", "etc"]
To see a list of subscriptions your account can access use the PowerShell command "Get-AzSubscription". The ID field is the subscription ID.

.PARAMETER locations
A list of locations for each of the above subscriptions to gather quota information on. This is formatted ["South Africa North", "UK West", "etc"]
To get a list of locations use the PowerShell command "Get-AzLocation". Either Displayname or Location fields can be used.

#>

Param(
 [string]$omsWorkspaceId,
 [string]$omsSharedKey,
 [string]$Locations
)

$omsWorkspaceId = Get-AutomationVariable -Name 'LAWorkspaceId'
$omsSharedKey = Get-AutomationVariable -Name 'LASharedKey'
$Locations = Get-AutomationVariable -Name 'Locations'

#If user gives the Location list with comma seperated....
[string[]] $AzLocations = $Locations -split ","  

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

$LogType = "AzureQuota"
 
 
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
 
# Network Usage not currently exposed through PowerShell, so need to call REST API
function Get-AzNetworkUsage($location, $SubscriptionId) 
{
    $token = Get-AzCachedAccessToken
    $authHeader = @{
    'Content-Type'='application\json'
    'Authorization'="Bearer $token"
    }
 
    $result = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Network/locations/$location/usages?api-version=2019-06-01" -Method Get -Headers $authHeader
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

# Get VM quotas
foreach ($AzLoc in $AzLocations)
{
    $vmQuotas = Get-AzVMUsage -location $AzLoc
    foreach($vmQuota in $vmQuotas)
    {
        $usage = 0
        if ($vmQuota.Limit -gt 0) { $usage = $vmQuota.CurrentValue / $vmQuota.Limit }
        $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($vmQuota.Name.LocalizedValue)", "Category":"Compute", "Location":"$AzLoc", "CurrentValue":$($vmQuota.CurrentValue), "Limit":$($vmQuota.Limit),"Usage":$usage },
"@
    }
}

# Get Network Quota
foreach ($AzLoc in $AzLocations)
{
    $networkQuotas = Get-AzNetworkUsage -location $AzLoc -SubscriptionId $SubscriptionId
    foreach ($networkQuota in $networkQuotas)
    {
        $usage = 0
        if ($networkQuota.limit -gt 0) { $usage = $networkQuota.currentValue / $networkQuota.limit }
         $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($networkQuota.name.localizedValue)", "Category":"Network", "Location":"$AzLoc", "CurrentValue":$($networkQuota.currentValue), "Limit":$($networkQuota.limit),"Usage":$usage },
"@
    }
 
}

# Get Storage Quota
foreach ($AzLoc in $AzLocations)
{
    $storageQuota = Get-AzStorageUsage -Location $AzLoc
    $usage = 0
    if ($storageQuota.Limit -gt 0) { $usage = $storageQuota.CurrentValue / $storageQuota.Limit }
    $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($storageQuota.LocalizedName)", "Location":"$AzLoc", "Category":"Storage", "CurrentValue":$($storageQuota.CurrentValue), "Limit":$($storageQuota.Limit),"Usage":$usage }
"@
}
# Wrap in an array
$json = "[$json]"
write-output $json
 
# Submit the data to the API endpoint
Post-OMSData -omsWorkspaceId $omsWorkspaceId -omsSharedKey $omsSharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
}

