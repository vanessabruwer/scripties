# AMA Migration Helper

This script helps to extract the current status of Azure VMs for tracking migration from the Microsoft Monitoring Agent (legacy agent) to the Azure Monitor Agent.

This script does not replace all the capabilities of the [AMA Migration Helper workbook](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-helper-workbook). Instead, it is a supplement to the workbook to quickly export Azure VMs, as well as the status of the MMA and AMA extensions, especially in larger environments.

The script will not connect to any of the Log Analytics workspaces in the environment to confirm that the machine is sending a heartbeat.

## Requirements

* You will need to install the `Az.ResourceGraph` module following the instructions [here](https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-powershell#optional-module-installation)

* You will need at least reader access to each subscription that contains virtual machines.

## Running the script

To run this script, open the script in your favourite PowerShell script interface, such as the PowerShell ISE or Visual Studio Code, and connect to your Azure Environment. You can now run the script as is.

The script will step through each subscription you have access to and run an Azure Resource Graph query against this subscription. The results will be written into a `.csv` file in the `c:\temp` directory.

* Filename: The file saved will use the following naming convention: AMAMigrationTracker-[randomnumber]-[date in format of yyyy-MM-dd].csv. You can update this in the variables at the top of the script

* File location: If you want to save this file to a different location, you can update this in the variables at the top of the script.