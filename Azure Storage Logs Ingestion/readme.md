## Azure Storage Log ingestion

This script is based on the script found [here][originalscript], which shows how to use  Azure Storage Powershell to collect the logs from a specific storage account and write the contents into a custom table in Log Analytics using the HTTP data ingestion API.
This script has been modified to be used in an Azure Automation runbook, to enumerate all the storage accounts in a subscription, and then step through each of them to collect the logs. It will also only collect the logs from the previous hour.

To use this script, you will need:
* An Azure Automation account
* Classic diagnostics enabled on your storage accounts

To implement:
* Import the Az.Storage module into your Automation account
* Create variables in Azure Automation for your Logs workspace ID and Key
* Create a new runbook with the script

All data will be written into the AzureStorage_CL custom log.


I have also included a workbook for data visualisation.






[originalscript]:https://github.com/Azure/azure-docs-powershell-samples/tree/master/storage/post-storage-logs-to-log-analytics