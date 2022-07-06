# Sentinel - Update a watchlist from a KQL query

This sample playbook shows how you can update a Watchlist in Microsoft Sentinel based on the output of a KQL query.

In this example, we are querying AAD Signin logs for all logon failures with this query:

> SigninLogs 
> | extend errorCode = tostring(Status.errorCode)
> | where errorCode <> 0
> | distinct UserPrincipalName, UserDisplayName


It then updates a pre-created watchlist called AADFailedLogonUsers.


Use this button to deploy the Logic App to your environment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanessabruwer%2Fscripties%2Fmaster%2FSentinel-UpdateWatchlistFromQuery%2Fazuredeploy.json)

Once deployed, you will need to edit the connections as relevant for your environment:

<img src="Screenshot 2022-07-06 152715.png">

<img src="Screenshot 2022-07-06 153133.png">

<img src="Screenshot 2022-07-06 153215.png">