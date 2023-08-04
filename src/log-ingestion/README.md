# Log Ingestion Azure Function

This project sets up `LogsIngestion` Azure Function that uploads custom logs to Azure Monitor.

It is Azure Blob Storage trigger function. Whenever a new file containing custom logs is uploaded to Azure Storage container, the function is triggered. The content of the file is parsed and sent to a custom table called `AirflowLogs_CL` in a Log Analytics workspace.

## Setup

* Follow [this tutorial](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-portal) to setup a data collection endpoint, a data collection rule, a custom table in a Log Analytics workspace, and grant correct permissions.
* Create Azure Function App with .NET runtime stack, and version 6.
* Setup required configuration in the Function App:
  * `airflowlogs_STORAGE` - a connection string of the Storage Account
  * `DataCollectionEndpoint`
  * `DataCollectionRuleId`
  * `AZURE_CLIENT_ID`
  * `AZURE_TENANT_ID`
  * `AZURE_CLIENT_SECRET`
* Open Visual Studio Code and Deploy function using [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions) by executing command `Azure Functions: Deploy to Function App...`.

## TODO

* Use Managed Identity instead of environment variables
* Explain steps for creating data collection rule
