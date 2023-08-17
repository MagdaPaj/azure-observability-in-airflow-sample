# Log Ingestion Azure Function

This project sets up `LogsIngestion` Azure Function that uploads custom logs from Azure Blob Storage to Azure Monitor.

For more details refer to the following [architecture overview](./../../README.md#architecture-overview).

The function is agnostic of Airflow, and with proper setup, it will work with any other logs format uploaded to Azure Blob Storage.

It requires:

* an Azure Storage Account with a container named `logs`, where log files will be uploaded,
* a [data collection endpoint](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-endpoint-overview?tabs=portal) and a [data collection rule](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview) to be created. The data collection rule must "understand" the format of your logs, and apply any required transformations. Check [azure-monitor terraform module](./../infra/azure-monitor/main.tf) to see how this configuration was done for Airflow logs and adapt it to your needs.

The project contains [log-ingestion-function terraform module](./../infra/logs-ingestion-function/main.tf), which can be reused and deployed independently.
