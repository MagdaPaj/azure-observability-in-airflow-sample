# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.68.0"
    }
  }

  required_version = ">= 1.5.4"
}

provider "azurerm" {
  features {}
}

resource "random_id" "random_name" {
  byte_length = 4
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "West Europe"
}

# Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = "rg-airflowlogs-${random_id.random_name.hex}"
  location = var.location
}

# Storage Account
resource "azurerm_storage_account" "log_storage_account" {
  name                     = "stairflowlogs${random_id.random_name.hex}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Blob Container
resource "azurerm_storage_container" "blob_container" {
  name                  = "airflow-logs"
  storage_account_name  = azurerm_storage_account.log_storage_account.name
  container_access_type = "private"
}

output "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER" {
  value = "wasb://${azurerm_storage_container.blob_container.name}@${azurerm_storage_account.log_storage_account.name}.blob.core.windows.net"
}

output "AZURE_BLOB_HOST" {
  value = "${azurerm_storage_account.log_storage_account.name}"
}

output "AZURE_BLOB_PASSWORD" {
  sensitive = true
  value = "${azurerm_storage_account.log_storage_account.primary_access_key}"
}

output "AZURE_BLOB_CONNECTION_STRING" {
  sensitive = true
  value = "${azurerm_storage_account.log_storage_account.primary_connection_string}"
}


resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "la-workspace-${random_id.random_name.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
}

resource "null_resource" "create_custom_table" {
  provisioner "local-exec" {
    command = "az monitor log-analytics workspace table create --resource-group ${azurerm_resource_group.resource_group.name} --workspace-name ${azurerm_log_analytics_workspace.log_analytics.name} -n AirflowLogs_CL --columns Application=string LogLevel=string LogTimestamp=datetime Message=string Method=string TimeGenerated=datetime"
  }
}

resource "azurerm_monitor_data_collection_endpoint" "logs_collection_endpoint" {
  name                = "airflow-logs-dce-${random_id.random_name.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_monitor_data_collection_rule" "logs_collection_rule" {
  name                        = "airflow-logs-dcr-${random_id.random_name.hex}"
  resource_group_name         = azurerm_resource_group.resource_group.name
  location                    = azurerm_resource_group.resource_group.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.logs_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics.id
      name                  = "airflow-logs-destination"
    }
  }

  data_flow {
    streams       = ["Custom-AirflowLogs_CL"]
    destinations  = ["airflow-logs-destination"]
    output_stream = "Custom-AirflowLogs_CL"
    transform_kql = "source\n| extend TimeGenerated = todatetime(Time)\n| parse RawData with * \"[\" LogTimestamp:datetime \"] {\" Method:string \"} \" LogLevel:string \" - \" Message:string\n| project-away Time, RawData\n// | where Method contains \"docker.py\"\n"
  }


  data_sources {
  }

  stream_declaration {
    stream_name = "Custom-AirflowLogs_CL"
    column {
      name = "Time"
      type = "datetime"
    }
    column {
      name = "RawData"
      type = "string"
    }
    column {
      name = "Application"
      type = "string"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  description = "Data collection rule for Airflow logs"
  depends_on = [ null_resource.create_custom_table ]
}

resource "azurerm_storage_account" "function_app_storage" {
  name                     = "stfunctionapp${random_id.random_name.hex}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "logs_ingestion" {
  name                = "logs-ingestion-service-plan-${random_id.random_name.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "logs_ingestion" {
  name                          = "logs-ingestion-${random_id.random_name.hex}"
  resource_group_name           = azurerm_resource_group.resource_group.name
  location                      = azurerm_resource_group.resource_group.location
  service_plan_id               = azurerm_service_plan.logs_ingestion.id
  storage_account_name          = azurerm_storage_account.function_app_storage.name
  storage_uses_managed_identity = true

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.logs_ingestion.connection_string
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.function_app_storage.name
    "AirflowLogsStorage__accountName" = azurerm_storage_account.log_storage_account.name
    "DataCollectionEndpoint" = azurerm_monitor_data_collection_endpoint.logs_collection_endpoint.logs_ingestion_endpoint
    "DataCollectionRuleId" = azurerm_monitor_data_collection_rule.logs_collection_rule.immutable_id
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.function_app_storage.primary_connection_string
    "WEBSITE_RUN_FROM_PACKAGE" = 1
  }

  site_config {
  }
}

resource "azurerm_application_insights" "logs_ingestion" {
  name                = "appi-${random_id.random_name.hex}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
  application_type    = "web"
}

resource "azurerm_role_assignment" "metrics_publisher_for_dcr" {
  scope                = azurerm_monitor_data_collection_rule.logs_collection_rule.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

# The use of managed identities to access Blob Storage requires a few roles to be set up corectly:
# https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-trigger?tabs=python-v2%2Cin-process&pivots=programming-language-csharp#grant-permission-to-the-identity

resource "azurerm_role_assignment" "access_to_func_storage_1" {
  scope                = azurerm_storage_account.function_app_storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_func_storage_2" {
  scope                = azurerm_storage_account.function_app_storage.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_func_storage_3" {
  scope                = azurerm_storage_account.function_app_storage.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_log_storage_1" {
  scope                = azurerm_storage_account.log_storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_log_storage_2" {
  scope                = azurerm_storage_account.log_storage_account.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}