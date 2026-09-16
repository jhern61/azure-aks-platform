# User-assigned managed identity for the AKS control plane.
# Decouples identity lifecycle from the cluster — allows RBAC grants before
# cluster creation and survives cluster replacement without losing role assignments.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  # Security posture: local accounts off, Entra ID + Azure RBAC for authn/authz.
  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_size
    vnet_subnet_id               = var.node_subnet_id
    orchestrator_version         = var.kubernetes_version
    only_critical_addons_enabled = true

    # Autoscaling — minimum 2 nodes for HA on system-critical pods (CoreDNS etc.)
    auto_scaling_enabled = true
    min_count            = var.system_node_min
    max_count            = var.system_node_max

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "managedNATGateway"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  monitor_metrics {
    # Enables the managed Prometheus metrics addon.
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Node count on the system pool drifts if the autoscaler ever touches it.
      default_node_pool[0].node_count,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_size
  vnet_subnet_id        = var.node_subnet_id
  orchestrator_version  = var.kubernetes_version

  auto_scaling_enabled = true
  min_count            = var.user_node_min
  max_count            = var.user_node_max

  upgrade_settings {
    max_surge = "33%"
  }

  node_labels = {
    "workload" = "general"
  }

  tags = var.tags
}

# Wire managed Prometheus scraping to the Azure Monitor workspace.
resource "azurerm_monitor_data_collection_endpoint" "prom" {
  name                = "dce-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "prom" {
  name                        = "dcr-${var.name}-prom"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom.id
  kind                        = "Linux"
  tags                        = var.tags

  destinations {
    monitor_account {
      monitor_account_id = var.prometheus_workspace_id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "prom" {
  name                    = "dcra-${var.name}-prom"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prom.id
}
