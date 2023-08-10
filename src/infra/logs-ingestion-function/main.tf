variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "random_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "data_collection_endpoint" {
  type = string
}

variable "data_collection_rule_immutable_id" {
  type = string
}

variable "data_collection_rule_id" {
  type = string
}

variable "raw_logs_storage_account_id" {
  type = string
}

variable "raw_logs_storage_account_name" {
  type = string
}

resource "azurerm_storage_account" "logs_ingestion" {
  name                     = "stlogsingestfunc${var.random_id}"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "logs_ingestion" {
  name                = "logs-ingestion-${var.random_id}"
  resource_group_name = var.rg_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "logs_ingestion" {
  name                = "logs-ingestion-${var.random_id}"
  resource_group_name = var.rg_name
  location            = var.location

  storage_uses_managed_identity = true
  storage_account_name          = azurerm_storage_account.logs_ingestion.name
  service_plan_id               = azurerm_service_plan.logs_ingestion.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING"    = azurerm_application_insights.logs_ingestion.connection_string
    "AzureWebJobsStorage__accountName"         = azurerm_storage_account.logs_ingestion.name
    "AirflowLogsStorage__accountName"          = var.raw_logs_storage_account_name
    "DataCollectionEndpoint"                   = var.data_collection_endpoint
    "DataCollectionRuleId"                     = var.data_collection_rule_immutable_id
    "FUNCTIONS_EXTENSION_VERSION"              = "~4"
    "FUNCTIONS_WORKER_RUNTIME"                 = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.logs_ingestion.primary_connection_string
    "WEBSITE_RUN_FROM_PACKAGE" = 1
  }

  site_config {
  }
}

resource "azurerm_application_insights" "logs_ingestion" {
  name                = "appi-logs-ingestion-${var.random_id}"
  resource_group_name = var.rg_name
  location            = var.location
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
}

resource "azurerm_role_assignment" "metrics_publisher_for_dcr" {
  scope                = var.data_collection_rule_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

# The use of managed identities to access Blob Storage requires a few roles to be set up corectly:
# https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-trigger?tabs=python-v2%2Cin-process&pivots=programming-language-csharp#grant-permission-to-the-identity

resource "azurerm_role_assignment" "access_to_func_storage_1" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_func_storage_2" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_func_storage_3" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_log_storage_1" {
  scope                = var.raw_logs_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "access_to_log_storage_2" {
  scope                = var.raw_logs_storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}
