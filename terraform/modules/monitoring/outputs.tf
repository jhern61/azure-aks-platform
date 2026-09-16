output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "prometheus_workspace_id" {
  value = azurerm_monitor_workspace.prometheus.id
}

output "grafana_endpoint" {
  value = azurerm_dashboard_grafana.this.endpoint
}

output "grafana_id" {
  value = azurerm_dashboard_grafana.this.id
}
