# Tags to Log Analytics data

You can use this script in an Azure Automation runbook to extract tag information about your virtual machines (both Azure-based and Arc-enabled) and write it into a custom table in Log Analytics.

A good use case for this is creating custom groups for Update Management for your non-Azure machines, since the tags are not exposed for the Hybrid machines yet.

I use the tag Department in my environment, so the query extracts that tag. You can update the query on line 140 to extract the tags you are using in your environment

In this script, I am sending everything to the Tags table, you can change this on line 51.

Sample query after run:

> Heartbeat
| distinct Computer, ResourceId
| join (
Tags_CL
| distinct ResourceId, Name_s, Department_s
) on ResourceId

-----------

To use this script, you will need:

1. An Azure Automation account
2. To create two encrypted variables:
* LAWorkspaceId for your workspace ID
* LASharedKey for your workspace shared key
3. A Powershell runbook, containing the contents of this script and linked to the schedule of your choice

The script does cycle through subscriptions, so for each subscription you want to read, you will need to grant the automation run-as account read rights to the subscription.