# Variables
$workspacename = "workspacename"
$wsrgname = "resourcegroupname for workspace"


# Output file
$ReportDate = Get-Date -format "yyyy-M-dd"
$LocalPath = "c:\temp"
$FileName = "$ReportDate-SentinelRules.csv"
$OutFile = "$LocalPath\$FileName"


# Check if folder exists, if not, create it
 if (!(Test-Path $LocalPath)){
 
 New-Item $LocalPath -type Directory | Out-Null

 }

# Delete any previous versions of the report for in case

If (Test-Path $OutFile){
	 Remove-Item $OutFile
}


# Open the content
$body = @()

$body += "Rule Name, Enabled, Rule Type, Tactics, LastModified"


#Check if the Az.SecurityInsights module is installed, if not install it
#This will auto install the Az.Accounts module if it is not installed
$AzSecurityInsightsModule = Get-InstalledModule -Name Az.SecurityInsights -ErrorAction SilentlyContinue
if ($AzSecurityInsightsModule -eq $null) {
    Write-Warning "The Az.SecurityInsights PowerShell module is not found"
        #check for Admin Privleges
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

        if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
            #Not an Admin, install to current user
            Write-Warning -Message "Can not install the Az.SecurityInsights module. You are not running as Administrator"
            Write-Warning -Message "Installing Az.SecurityInsights module to current user Scope"
            Install-Module Az.SecurityInsights -Scope CurrentUser -Force
        }
        Else {
            #Admin, install to all users
            Write-Warning -Message "Installing the Az.SecurityInsights module to all users"
            Install-Module -Name Az.SecurityInsights -Force
            Import-Module -Name Az.SecurityInsights -Force
        }
}


# Export Rules
$sentinelrules = Get-AzSentinelAlertRule -ResourceGroupName $wsrgname -WorkspaceName $workspacename

foreach($rule in $sentinelrules)
{

    $Name = $rule.DisplayName
    $enabled = $rule.Enabled
    $type = $rule.Kind
    $tactics = $rule.Tactics
    $lastmodified = $rule.LastModifiedUtc


    $body += "$Name,$enabled,$type,$tactics,$lastmodified"


}

$body >> $OutFile

Write-Host ("Azure Analytics Rules are exported to " + $OutFile) -ForegroundColor Yellow