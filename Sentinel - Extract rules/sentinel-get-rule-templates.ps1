$ReportDate = Get-Date -format "yyyy-M-dd"
$ReportLocation = "C:\temp"
$ReportName = "Sentinel-Analytics-RuleTemplates-$ReportDate.csv"
$SavetoFile = "$ReportLocation\$ReportName"

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


get-azsentinelalertruletemplate -ResourceGroupName "$ResourceGroup" -WorkspaceName "$WorkspaceName" | Select-Object DisplayName, Status, Kind, RequiredDataConnectors, Severity | Export-Csv $SavetoFile -NoTypeInformation