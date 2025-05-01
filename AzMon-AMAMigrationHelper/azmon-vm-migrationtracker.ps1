# Variables

$ReportDate = Get-Date -format "yyyy-M-dd"
$ReportLocation = "C:\temp"
$rnd = Get-Random -minimum 1 -maximum 1000
$ReportName = "AMAMigrationTracker-$rnd-$ReportDate.csv"
$SavetoFile = "$ReportLocation\$ReportName"

 # Delete any previous versions of the report for in case

If (Test-Path $SavetoFile){
	Remove-Item $SavetoFile
}


# Open the content
$body = @()

# Set the file header
$body += "Subscription, ComputerName, Resource ID, Location, Resource Group, PowerStatus, MMA, MMA Status, Managed Identity, AMA, AMA Status, AMA Version, Progress"

# Import the Az.ResourceGraph module
Import-Module Az.ResourceGraph

# Connect to Azure
#Connect-AzAccount

#Connect to subscription
$subs=get-azsubscription
$currentsub=(Get-AzContext).Subscription.Name
write-host "Current subscription is $currentsub"

foreach ($sub in $subs) {

$subid = $sub.Id

$query = @"
resources
| where type == 'microsoft.compute/virtualmachines' and subscriptionId == '$subid'
| extend PowerStatus = tostring(properties.extended.instanceView.powerState.displayStatus),
OSType = tostring(properties.storageProfile.osDisk.osType),
IdentityType = tostring(identity.type),
ComputerName = tolower(name),
vmid = tolower(id)
| extend IdentityType = iff(isempty(IdentityType), 'No Managed Identity Assigned', 'Managed Identity Assigned')
| order by vmid asc
| project ComputerName, vmid, location, resourceGroup, PowerStatus, OSType, tostring(IdentityType), subscriptionId
| join kind=leftouter (
resources
| where type contains 'microsoft.compute/virtualmachines/extensions' and subscriptionId == '$subid'
| extend publisher = properties.publisher
| where publisher =~ "Microsoft.EnterpriseCloud.Monitoring"
| parse id with * '/virtualMachines/' ComputerName '/' *
| parse id with vmid '/extensions/' *
| extend extensionType = properties.type, 
status = properties.provisioningState,
version = properties.typeHandlerVersion,
ComputerName = tolower(ComputerName),
vmid = tolower(vmid)
| order by vmid asc
| project vmid, ComputerName, MMA = tostring(name), MMAStatus = tostring(status), tostring(version)
) on vmid
| join kind=leftouter (
resources
| where type contains 'microsoft.compute/virtualmachines/extensions' and subscriptionId == '$subid'
| extend publisher = properties.publisher
| where publisher =~ 'Microsoft.Azure.Monitor'
| parse id with * '/virtualMachines/' ComputerName '/' *
| parse id with vmid '/extensions/' *
| extend extensionType = properties.type, 
status = properties.provisioningState,
version = properties.typeHandlerVersion,
ComputerName = tolower(ComputerName),
vmid = tolower(vmid)
| order by vmid asc
| project vmid, ComputerName, AMA = tostring(name), AMAStatus = tostring(status), AMAVersion = tostring(version)
) on vmid
| extend Progress = case(isnotempty(MMA) and isnotempty(AMA), 'In Progress',
                        isnotempty(MMA) and isempty(AMA), 'Not Started',
                        isempty(MMA) and isnotempty(AMA), 'Completed', 'Other')
| extend MMA = iff(isempty(MMA), 'Not Installed', MMA)
| extend AMA = iff(isempty(AMA), 'Not Installed', AMA)
| extend IdentityType = parse_json(IdentityType)
| distinct subscriptionId, ComputerName, vmid, location, resourceGroup, OSType, PowerStatus, MMA, MMAStatus, tostring(IdentityType), AMA, AMAStatus, AMAVersion, Progress
| order by vmid
"@

$queryresults = Search-AzGraph -Query $query

	# step through each of the results and add it to the content for the output
	foreach ($result in $queryresults){

#Write-Host $result
	
	 $ComputerName = $result.ComputerName
	 $ResourceId = $result.vmid
	 $Location = $result.location
	 $ResourceGroup = $result.resourceGroup
	 $PowerStatus = $result.PowerStatus
	 $MMA = $result.MMA
	 $MMAStatus = $result.MMAStatus
	 $ManagedIdentity = $result.IdentityType
	 $AMA = $result.AMA
	 $AMAStatus = $result.AMAStatus
	 $AMAVersion = $result.AMAVersion
	 $Progress = $result.Progress
	
Write-Output "$sub, $ComputerName, $ResourceId, $Location, $ResourceGroup, $PowerStatus, $MMA, $MMAStatus, $ManagedIdentity, $AMA, $AMAStatus, $AMAVersion, $Progress"

	 # Compile output
	 $reportoutput = "$sub, $ComputerName, $ResourceId, $Location, $ResourceGroup, $PowerStatus, $MMA, $MMAStatus, $ManagedIdentity, $AMA, $AMAStatus, $AMAVersion, $Progress"
	 $body += $reportoutput
	}
}

# Save the report to file
$body | Out-File -FilePath $SavetoFile -Encoding utf8