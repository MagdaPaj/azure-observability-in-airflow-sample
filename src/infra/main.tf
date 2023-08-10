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
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "random_id" "random_name" {
  byte_length = 4
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "West Europe"
}

variable "function_project_path" {
  type    = string
  default = "../log-ingestion"
}

resource "azurerm_resource_group" "resource_group" {
  name     = "rg-logs-ingestion-${random_id.random_name.hex}"
  location = var.location
}

module "raw_airflow_logs_storage" {
  source    = "./raw-logs-storage"
  rg_name   = azurerm_resource_group.resource_group.name
  location  = var.location
  random_id = random_id.random_name.hex
}

module "azure_monitor" {
  source    = "./azure-monitor"
  rg_name   = azurerm_resource_group.resource_group.name
  location  = var.location
  random_id = random_id.random_name.hex
}

module "logs_ingestion_function" {
  source                            = "./logs-ingestion-function"
  rg_name                           = azurerm_resource_group.resource_group.name
  location                          = var.location
  random_id                         = random_id.random_name.hex
  raw_logs_storage_account_id       = module.raw_airflow_logs_storage.airflow_logs_storage_account_id
  raw_logs_storage_account_name     = module.raw_airflow_logs_storage.airflow_logs_storage_account_name
  log_analytics_workspace_id        = module.azure_monitor.log_analytics_workspace_id
  data_collection_endpoint          = module.azure_monitor.data_collection_endpoint
  data_collection_rule_immutable_id = module.azure_monitor.data_collection_rule_immutable_id
  data_collection_rule_id           = module.azure_monitor.data_collection_rule_id
  function_project_path             = var.function_project_path
}

output "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER" {
  value = module.raw_airflow_logs_storage.airflow_logging_remote_base_log_folder
}

output "AZURE_BLOB_HOST" {
  value = module.raw_airflow_logs_storage.airflow_logs_storage_account_name
}

output "AZURE_BLOB_PASSWORD" {
  sensitive = true
  value     = module.raw_airflow_logs_storage.airflow_logs_blob_password
}

output "AZURE_BLOB_CONNECTION_STRING" {
  sensitive = true
  value     = module.raw_airflow_logs_storage.airflow_logs_storage_account_connection_string
}
