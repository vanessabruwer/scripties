# Enriched Alert Dashboards

This solution contains a Logic App and a Azure Monitor Workbook to support [this blog post][blogpost]

**The Logic App** is triggered as a response on a [Log Based alert][logalerts] configured in the Action Group. The Logic App will extract the alert details, and then use the [HTTP Data Collector API][httpapi] to write the alert detail back into a custom table. This table can then be queried for presentation purposes.

Deploy Logic App using the button below. For this deployment, you will need the following information:
<ul>
<li>Workspace ID</li>
<li>Workspace Key</li>
</ul>

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanessabruwer%2Fscripties%2Fmaster%2FAlert%2520Dashboard%2520Solution%2Fazuredeploy.json)

**The Workbook** is a sample showing the alerts that have been written in to the custom table usign the Logic App. To use the workbook, create a new workbook, and copy the code from this sample into the code area for the workbook, replacing the sample code in this workbook:

<img src="workbook-code.png">


[blogpost]:https://cloudbunnies.wordpress.com/2019/11/04/azuremonitor-building-an-enriched-alerts-dashboard-with-logicapps-and-loganalytics-data-collector-api/
[logalerts]:https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-unified-log
[httpapi]:https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-collector-api
