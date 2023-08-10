variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "random_id" {
  type = string
}

variable "raw_logs_storage_account_connection_string" {
  type      = string
  sensitive = true
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

  storage_account_name       = azurerm_storage_account.logs_ingestion.name
  storage_account_access_key = azurerm_storage_account.logs_ingestion.primary_access_key
  service_plan_id            = azurerm_service_plan.logs_ingestion.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "airflowlogs_STORAGE"                      = var.raw_logs_storage_account_connection_string
    "APPLICATIONINSIGHTS_CONNECTION_STRING"    = azurerm_application_insights.logs_ingestion.connection_string
    "AzureWebJobsStorage"                      = azurerm_storage_account.logs_ingestion.primary_connection_string
    "DataCollectionEndpoint"                   = var.data_collection_endpoint
    "DataCollectionRuleId"                     = var.data_collection_rule_immutable_id
    "FUNCTIONS_EXTENSION_VERSION"              = "~4"
    "FUNCTIONS_WORKER_RUNTIME"                 = "dotnet"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.logs_ingestion.primary_connection_string
    # "WEBSITE_CONTENTSHARE" = 
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
