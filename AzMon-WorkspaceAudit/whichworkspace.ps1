# Variables

$ReportDate = Get-Date -format "yyyy-M-dd"
$ReportLocation = "C:\temp"
$ReportName = "WhichWorkspace-$ReportDate.csv"
$SavetoFile = "$ReportLocation\$ReportName"

 # Delete any previous versions of the report for in case

If (Test-Path $SavetoFile){
	Remove-Item $SavetoFile
}


# Open the content
$body = @()

# Set the file header
$body += "Subscription, ResourceGroup, Workspace, AgentResourceId, Computer, AgentRG, AgentSub, OSType, Environment"


#Connect to subscription
$subs=get-azsubscription
$currentsub=(Get-AzContext).Subscription.Name
write-host "Current subscription is $currentsub"

foreach ($sub in $subs) {
    # get log analytis workspaces for subscription
    if ($sub.Id -ne $currentsub) {
        Set-AzContext -SubscriptionId $sub.Id | Out-Null
        "Switched to $($sub.Name) subscription."
        $currentsub=$sub.Id
    }
    $workspaces = Get-AzResource -ResourceType "Microsoft.OperationalInsights/workspaces" 
    
    # Step through each of the workspaces
    foreach ($ws in $workspaces) {

    $wsid = $ws.ResourceId
    $wsrg = $ws.ResourceGroupName
    $wsname = $ws.Name

    # get the workspace property for the query
    $workspace = Get-AzOperationalInsightsWorkspace -Name $wsname -ResourceGroupName $wsrg
 

    # define and run the query against the current workspace
    $query = "Heartbeat | summarize arg_max(TimeGenerated, *) by ResourceId | where TimeGenerated > ago(24h) | project _ResourceId, Computer, ResourceGroup, SubscriptionId, OSType, ComputerEnvironment" 
    $queryresults = Invoke-AzOperationalInsightsQuery -Workspace $workspace -Query $query # | select -ExpandProperty Results

    # step through each of the results and add it to the content for the output
    foreach ($result in $queryresults.Results){
    
     $resourceid = $result._ResourceId
     $Computer = $result.Computer
     $comprg = $result.ResourceGroup
     $compsub = $result.SubscriptonId
     $OS = $result.OSType
     $Environment = $result.ComputerEnvironment

     #$currentsub, $wsrg, $wsname, $resourceid, $Computer, $comprg, $compsub, $OS, $Environment

     # Compile output
     $reportoutput = "$currentsub, $wsrg, $wsname, $resourceid, $Computer, $comprg, $compsub, $OS, $Environment"
     $body += $reportoutput 
    
    }
 }
    
}

#Write the output to the file
$body >> $SavetoFile