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

variable "data_collection_rule_stream_name" {
  type = string
}

variable "raw_logs_storage_account_id" {
  type = string
}

variable "raw_logs_storage_account_name" {
  type = string
}

variable "function_project_path" {
  type = string
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
  functions_extension_version   = "~4"

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "LogsStorage__accountName"     = var.raw_logs_storage_account_name
    "DataCollectionEndpoint"       = var.data_collection_endpoint
    "DataCollectionRuleId"         = var.data_collection_rule_immutable_id
    "DataCollectionRuleStreamName" = var.data_collection_rule_stream_name
    "FUNCTIONS_WORKER_RUNTIME"     = "dotnet"
    "WEBSITE_RUN_FROM_PACKAGE"     = azurerm_storage_blob.logs_ingestion.url
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.logs_ingestion.connection_string
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "logs_ingestion" {
  name                     = "stlogsingestfunc${var.random_id}"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Required resources to make use of WEBSITE_RUN_FROM_PACKAGE, which provides a link to a zip-file, containing the LogIngestion Azure Function.
# The zip-file is created through terraform and uploaded to a Blob Storage.

resource "azurerm_storage_container" "logs_ingestion" {
  name                 = "function-release"
  storage_account_name = azurerm_storage_account.logs_ingestion.name
}

resource "azurerm_storage_blob" "logs_ingestion" {
  name                   = "logs_ingestion_func.zip"
  storage_account_name   = azurerm_storage_account.logs_ingestion.name
  storage_container_name = azurerm_storage_container.logs_ingestion.name
  type                   = "Block"
  content_md5            = data.archive_file.function.output_md5
  source                 = "${var.function_project_path}/logs_ingestion_func.zip"
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${var.function_project_path}/Deployment"
  output_path = "${var.function_project_path}/logs_ingestion_func.zip"

  depends_on = [null_resource.dotnet_publish]
}

resource "null_resource" "dotnet_publish" {
  triggers = {
    host_file          = "${filemd5("${var.function_project_path}/host.json")}"
    log_ingestion_file = "${filemd5("${var.function_project_path}/LogsIngestion.cs")}"
    project_file       = "${filemd5("${var.function_project_path}/log-ingestion.csproj")}"
  }

  provisioner "local-exec" {
    command     = "dotnet publish -o ${var.function_project_path}/Deployment"
    working_dir = var.function_project_path
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

resource "azurerm_role_assignment" "blob_owner_access_to_func_storage" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "queue_contributor_access_to_func_storage" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "account_contributor_access_to_func_storage" {
  scope                = azurerm_storage_account.logs_ingestion.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "blob_owner_access_to_log_storage" {
  scope                = var.raw_logs_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}

resource "azurerm_role_assignment" "queue_contributor_access_to_log_storage" {
  scope                = var.raw_logs_storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_windows_function_app.logs_ingestion.identity[0].principal_id
}
