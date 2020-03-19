## Azure Storage Log ingestion

This script is based on the script found [here][originalscript], which shows how to use  Azure Storage Powershell to collect the logs from a specific storage account and write the contents into a custom table in Log Analytics using the HTTP data ingestion API.
This script has been modified to enumerate all the storage accounts in a subscription, and then step through each of them to collect the logs. It will also only collect the logs from the previous hour.

A workbook is planned for visualising the data collected :)








[originalscript]:https://github.com/Azure/azure-docs-powershell-samples/tree/master/storage/post-storage-logs-to-log-analytics