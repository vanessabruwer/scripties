# Azure Monitor Workspace Audit

## Overview

You can use this script to audit which workspaces your virtual machines, including Arc-enabled machines, are reporting to.

When you run this script, it will connect to your Azure environment, retrieve all the subscriptions, and look for Azure Monitor Logs workspaces in those subscriptions.
For each workspace found, it will run a KQL query against the workspace to retrieve all machines that have sent a heartbeat in the last 24 hours. It will then list each of these machines, along with Resource Group, Subscription and OS information.

All output will be written to a CSV file.

## How to use

1. Open your preferred Powershell environment that allows you to run Powershell cmdlets.
2. Connect to your environment by running

    `connect-AzAccount`

If you have a multi-tenant environment, you will need to run this script for each tenant, and connect to the tenant using the following cmdlet


    `connect-AzAccount -tenant 'tenant id here'`

You will be prompted to authenticate against the environment.

3. You can now open the script, if you are using an editor like VSCode or Powershell ISE, and execute it.


## Variables to update

All variables for this script are found at the top of the script, and should be updated to suit your requirements.

* $ReportDate = Get-Date -format "yyyy-M-dd" *# This will set the date format in the file name*
* $ReportLocation = "C:\temp" *# this is the save location where the file will be saved*
* $ReportName = "WhichWorkspace-$ReportDate.csv" *# this is the name of the file. In this format, it will append the report date to the name of the file, if you select to run it on a regular basis.*

The time period for the query (last 24 hours) is defined within the query on line 51 of the script. If you find you are missing machines, you may extend this time period to longer.

> **Note**: in larger environments, this may extend the run-time of the script and may lead to time-out errors.

