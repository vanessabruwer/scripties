$ReportDate = Get-Date -format "yyyy-M-dd"
$ReportLocation = "C:\temp"
$ReportName = "Sentinel-Analytics-RuleTemplates-$ReportDate.csv"
$SavetoFile = "$ReportLocation\$ReportName"

$subscriptionid = ""
$ResourceGroup = ""
$WorkspaceName = ""

# Check if folder exists, if not, create it
 if (!(Test-Path $ReportLocation)){
    New-Item $ReportLocation -type Directory | Out-Null
 }

# Delete any previous versions of the report for in case
If (Test-Path $SavetoFile){
	 Remove-Item $SavetoFile
}

# Connect to Azure and select subscription
Connect-AzAccount
Select-AzSubscription -Subscription $subscriptionid

# Get templates and export to CSV
$RuleTemplates = get-azsentinelalertruletemplate -ResourceGroupName "$ResourceGroup" -WorkspaceName "$WorkspaceName" | Select-Object DisplayName, Description, Status, Kind, Query, QueryFrequency, QueryPeriod, Severity, AlertRulesCreatedByTemplateCount
$RuleTemplates | Export-Csv $SavetoFile -NoTypeInformation