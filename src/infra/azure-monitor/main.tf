variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "random_id" {
  type = string
}

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "la-workspace-${var.random_id}"
  resource_group_name = var.rg_name
  location            = var.location
}

resource "null_resource" "create_custom_table" {
  provisioner "local-exec" {
    command = "az monitor log-analytics workspace table create --resource-group ${var.rg_name} --workspace-name ${azurerm_log_analytics_workspace.log_analytics.name} -n AirflowLogs_CL --columns Application=string LogLevel=string LogTimestamp=datetime Message=string Method=string TimeGenerated=datetime"
  }
}

resource "azurerm_monitor_data_collection_endpoint" "logs_collection_endpoint" {
  name                = "airflow-logs-dce-${var.random_id}"
  resource_group_name = var.rg_name
  location            = var.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_monitor_data_collection_rule" "logs_collection_rule" {
  name                        = "airflow-logs-dcr-${var.random_id}"
  resource_group_name         = var.rg_name
  location                    = var.location
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

  description = "Data collection rule for Airflow logs"

  depends_on = [null_resource.create_custom_table]
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.log_analytics.id
}

output "data_collection_endpoint" {
  value = azurerm_monitor_data_collection_endpoint.logs_collection_endpoint.logs_ingestion_endpoint
}

output "data_collection_rule_immutable_id" {
  value = azurerm_monitor_data_collection_rule.logs_collection_rule.immutable_id
}

output "data_collection_rule_id" {
  value = azurerm_monitor_data_collection_rule.logs_collection_rule.id
}
