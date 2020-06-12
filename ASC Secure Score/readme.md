This script leverages off the [Secure Score API](https://docs.microsoft.com/en-us/rest/api/securitycenter/securescores/list) to extract the ASC secure score for each subscription, and write it back to a custom table in the specified Log Analytics workspace.

Note: this script is formatted for use within an Azure Automation Runbook, and may need to be reformatted for use outside of AA.