# Windows Virtual Desktop

This workbook visualises the health and performance of WVD (Spring Release). To be able to use this workbook, you will need to enable the following:

1. VMInsights on the hosts
2. WVD Diagnostic Logs
3. Collection of the following performance counters in your Log Analytics workspace:

* `Terminal Services Session(*)\% Processor Time`
* `Terminal Services(*)\Active Sessions`
* `Terminal Services(*)\Inactive Sessions`
* `Terminal Services(*)\Total Sessions`
* `LogicalDisk(*)\% Free Space`
* `Processor(_Total)\% Processor Time`
* `Memory(*)\% Committed Bytes In Use`
* `Network Adapter(*)\Bytes Received/sec`
* `Network Adapter(*)\Bytes Sent/sec`
* `Process(*)\% Processor Time`
* `Process(*)\% User Time`
* `Process(*)\IO Read Operations/sec`
* `Process(*)\IO Write Operations/sec`
* `Process(*)\Thread Count`
* `Process(*)\Working Set`
