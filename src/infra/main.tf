# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
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
resource "azurerm_storage_account" "storage_account" {
  name                     = "saairflowlogs${random_id.random_name.hex}"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Blob Container
resource "azurerm_storage_container" "blob_container" {
  name                  = "airflow-logs"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

output "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER" {
  value = "wasb://${azurerm_storage_container.blob_container.name}@${azurerm_storage_account.storage_account.name}.blob.core.windows.net"
}

output "AZURE_BLOB_HOST" {
  value = "${azurerm_storage_account.storage_account.name}"
}

output "AZURE_BLOB_PASSWORD" {
  sensitive = true
  value = "${azurerm_storage_account.storage_account.primary_access_key}"
}

output "AZURE_BLOB_CONNECTION_STRING" {
  sensitive = true
  value = "${azurerm_storage_account.storage_account.primary_connection_string}"
}
