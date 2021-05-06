#################################################################
#
#   Azure Arc for Servers - Connected Agent Installation script
#
#   This script is intended to run as a start-up script configured in AD GPO
#
#   Follow instructions here to create Service Principal:
#   https://docs.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal
#
#
#################################################################


# variables
$KeytoCheck = "HKLM\SOFTWARE\Microsoft\Azure Connected Machine Agent"
$LocalPath = "c:\temp"
$FileName = "AzureConnectedMachineAgent.msi"
$OutFile = "$LocalPath\$FileName"
$LogFile = "$LocalPath\installationlog.txt"
$ScriptLog = "$LocalPath\scriptlog.txt"

################################################################

# Check if folder exists, if not, create it
 if (!(Test-Path $LocalPath)){
 
 New-Item $LocalPath -type Directory | Out-Null

 }

 # start logging
Start-Transcript -Path $ScriptLog
 
 # Check if the agent has been deployed and configured previously
 # We do this by checking for the registry key and value

 $keyexists = Test-Path $KeytoCheck
if ($keyexists -eq $True){
Write-Output "Installation skipped, it is possible that the Azure Arc for Servers agent is already installed"
}
else
{
Write-Output "Installation can proceed"

#check if the package exists
 if ((Test-Path $OutFile)){

 Write-Output "File already downloaded"
 }
 else
 {

# Download the package
function download() {$ProgressPreference="SilentlyContinue"; Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile $OutFile}
download

}

# Install the package
msiexec /i $OutFile /l*v $LogFile /qn | Out-String

# Run connect command
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id "spn id" `
  --service-principal-secret "spn secret" `
  --resource-group "resource group" `
  --tenant-id "tenant id" `
  --location "location" `
  --subscription-id "subscriptionid"

  }

  Stop-Transcript