variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "random_id" {
  type = string
}

resource "azurerm_storage_account" "airflow_logs" {
  name                     = "stairflowlogs${var.random_id}"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "airflow_logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.airflow_logs.name
  container_access_type = "private"
}

output "airflow_logging_remote_base_log_folder" {
  value = "wasb://${azurerm_storage_container.airflow_logs.name}@${azurerm_storage_account.airflow_logs.name}.blob.core.windows.net"
}

output "airflow_logs_storage_account_name" {
  value = azurerm_storage_account.airflow_logs.name
}

output "airflow_logs_blob_password" {
  sensitive = true
  value = azurerm_storage_account.airflow_logs.primary_access_key
}

output "airflow_logs_storage_account_connection_string" {
  sensitive = true
  value = azurerm_storage_account.airflow_logs.primary_connection_string
}

output "airflow_logs_storage_account_id" {
  value = azurerm_storage_account.airflow_logs.id
}
