# Description: This script shows how to post Az.Storage Analytics logs to Azure Log Analytics workspace
#
# Before running this script:
#     - Create or have a storage account, and enable analytics logs
#     - Create Azure Log Analytics workspace
#     - Change the following values:
#           - $omsWorkspaceId
#           - $omsSharedKey
#           - $LogType
#
# What this script does:
#     - Use Storage Powershell to enumerate all log blobs in $logs container in a storage account
#     - Use Storage Powershell to read all log blobs
#     - Convert each log line in the log blob to JSON payload
#     - Use Log Analytics HTTP Data Collector API to post JSON payload to Log Analytics workspace
#
# Note: This script is sample code. No support is provided.
#
# Reference:
#     - Log Analytics Data Collector API: https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api
#


Param(
 [string]$omsWorkspaceId,
 [string]$omsSharedKey,
 [string]$Subscriptions
)

$omsWorkspaceId = Get-AutomationVariable -Name 'LAWorkspaceId'
$omsSharedKey = Get-AutomationVariable -Name 'LASharedKey'
#$Subscriptions = Get-AutomationVariable -Name 'Subscriptions'



#Login-AzAccount

#######################################################################

# Create connection to Azure

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

#######################################################################

# Specify the name of the record type that you'll be creating
# After logs are sent to the workspace, you will use "MyStorageLogs1_CL" as stream to query.
$LogType = "AzureStorage"


#######################################################################


# Date components

$Year = (Get-Date).ToString('yyyy')
$Month = (Get-date).ToString('MM')
$Day = (Get-Date).ToString('dd')
$Hour = (get-date).AddHours(-1).ToString('HH')

$blobnamematch = 'blob/'+$Year+'/'+$month+'/'+$day+'/'+$hour+'00/'

#######################################################################

# Container name for analytics logs
$ContainerName = "`$logs"

#######################################################################

#
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
 
# Submit the data to the API endpoint
#Post-OMSData -omsWorkspaceId $omsWorkspaceId -omsSharedKey $omsSharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType

#
# Convert ; to "%3B" between " in the csv line to prevent wrong values output after split with ;
#
Function ConvertSemicolonToURLEncoding([String] $InputText)
{
    $ReturnText = ""
    $chars = $InputText.ToCharArray()
    $StartConvert = $false

    foreach($c in $chars)
    {
        if($c -eq '"') {
            $StartConvert = ! $StartConvert
        }

        if($StartConvert -eq $true -and $c -eq ';')
        {
            $ReturnText += "%3B"
        } else {
            $ReturnText += $c
        }
    }

    return $ReturnText
}

#
# If a text doesn't start with ", add "" for json value format
# If a text contains "%3B", replace it back to ";"
#
Function FormalizeJsonValue($Text)
{
    $Text1 = ""
    if($Text.IndexOf("`"") -eq 0) { $Text1=$Text } else {$Text1="`"" + $Text+ "`""}

    if($Text1.IndexOf("%3B") -ge 0) {
        $ReturnText = $Text1.Replace("%3B", ";")
    } else {
        $ReturnText = $Text1
    }
    return $ReturnText
}

Function ConvertLogLineToJson([String] $logLine)
{
    #Convert semicolon to %3B in the log line to avoid wrong split with ";"
    $logLineEncoded = ConvertSemicolonToURLEncoding($logLine)

    $elements = $logLineEncoded.split(';')

    $FormattedElements = New-Object System.Collections.ArrayList
                
    foreach($element in $elements)
    {
        # Validate if the text starts with ", and add it if not
        $NewText = FormalizeJsonValue($element)

        # Use "> null" to avoid annoying index print in the console
        $FormattedElements.Add($NewText) > null
    }

    $Columns = 
    (   "version-number",
        "request-start-time",
        "operation-type",
        "request-status",
        "http-status-code",
        "end-to-end-latency-in-ms",
        "server-latency-in-ms",
        "authentication-type",
        "requester-account-name",
        "owner-account-name",
        "service-type",
        "request-url",
        "requested-object-key",
        "request-id-header",
        "operation-count",
        "requester-ip-address",
        "request-version-header",
        "request-header-size",
        "request-packet-size",
        "response-header-size",
        "response-packet-size",
        "request-content-length",
        "request-md5",
        "server-md5",
        "etag-identifier",
        "last-modified-time",
        "conditions-used",
        "user-agent-header",
        "referrer-header",
        "client-request-id"
    )

    # Propose json payload
   $logJson = "{`"SubscriptionId`":`"$SubscriptionId`", `"Subscription`":`"$SubscriptionName`", `"ResourceGroup`":`"$ResourceGroup`", `"StorageAccountName`":`"$StorageAccountName`",";
    For($i = 0;$i -lt $Columns.Length;$i++)
    {
        $logJson += "`"" + $Columns[$i] + "`":" + $FormattedElements[$i]
        if($i -lt $Columns.Length - 1) {
            $logJson += ","
        }
    }
    $logJson += "}";

    return $logJson
}



#######################################################################

$Subscriptions = Get-AzSubscription

# for each subscription get the storage account info
foreach ($Subscription in $Subscriptions)
{

$Subscription = Get-AzSubscription -SubscriptionId $Subscription

Write-Output $Subscription

$SubscriptionId = $Subscription.Id
$SubscriptionName = $Subscription.Name

Write-Output $SubscriptionId

Set-AzContext -Subscription $SubscriptionId


# step through each resource group
$ResourceGroups = Get-AzResourceGroup | where {$_.ResourceId -like "*$SubscriptionId*"}


foreach ($ResourceGroup in $ResourceGroups)
{

$rgname = $ResourceGroup.ResourceGroupName

Write-Output $rgname


# Get Storage Accounts

$storageAccounts = Get-AzStorageAccount  -ResourceGroupName $rgname

# step through each storage account and get the logs
foreach($StorageAccount in $storageAccounts)
{

#map it out
$StorageAccountName = $StorageAccount.StorageAccountName
$ResourceGroup = $StorageAccount.ResourceGroupName
$SALocation = $StorageAccount.PrimaryLocation
$SASKU = $StorageAccount.SkuName

Write-Host $StorageAccountName



$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName -ErrorAction SilentlyContinue
if($storageAccount -eq $null)
{
    throw "The storage account specified does not exist in this subscription."
}

$storageContext = $storageAccount.Context
$containers = New-Object System.Collections.ArrayList
$container = Get-AzStorageContainer -Context $storageContext -Name "`$logs" -ErrorAction SilentlyContinue |
        ForEach-Object { $containers.Add($_) } | Out-Null

Write-Output("> Container count: {0}" -f $containers.Count)

$blobCount = 0
$Token = $Null
$MaxReturn = 5000
$SuccessPost = 0
$FailedPost = 0

# Enumerate containers
$containers | ForEach-Object {
    $Container = $_.CloudBlobContainer
    Write-Output("> Reading container {0}" -f $Container.Name)

    do {
        $Blobs = Get-AzStorageBlob -Context $storageContext -Container $Container.Name -MaxCount $MaxReturn -ContinuationToken $Token
        if($Blobs -eq $Null) {
            break
        }

        #Set-StrictMode will cause Get-AzStorageBlob returns result in different data types when there is only one blob
        if($Blobs.GetType().Name -eq "AzureStorageBlob") {
            $Token = $Null
        } else {
            $Token = $Blobs[$Blobs.Count - 1].ContinuationToken;
        }

        # Enumerate log blobs
        foreach($blob in $Blobs)
        {
            $blobName = $blob.name

            if($blobName -match $blobnamematch){

            Write-Output("> Downloading blob: {0}" -f $blob.Name)
            $filename = ".\log.txt"
            Get-AzStorageBlobContent -Context $storageContext -Container $Container.Name -Blob $blobName -Destination $filename -Force > Null
            
            Write-Output("> Posting logs to log analytic workspace: {0}" -f $blobName)
            $Lines = Get-Content $filename

            # Enumerate log lines in each log blob
            foreach($line in $Lines)
            {
                $jsonout = ConvertLogLineToJson($line)

$json = @"
$jsonout
"@

$json = "[$json]"

                
                Write-Output $json


                $Response = Post-OMSData -omsWorkspaceId $omsWorkspaceId -omsSharedKey $omsSharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType

                if($Response -eq "200") {
                    $SuccessPost++
                } else { 
                    $FailedPost++
                    Write-Output "> Failed to post one log to Log Analytics workspace"
                }
            }
        }
        }
    }
    While ($Token -ne $Null)

    Write-Output "> Log lines posted to Log Analytics workspace: success = $SuccessPost, failure = $FailedPost"
}
}
}
}
