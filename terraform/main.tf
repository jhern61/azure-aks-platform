locals {
  name = "${var.prefix}-${var.environment}"

  base_tags = {
    project     = "azure-aks-platform"
    environment = var.environment
    managed_by  = "terraform"
    owner       = "sre"
  }

  tags = merge(local.base_tags, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  log_retention_days  = var.log_retention_days
  tags                = local.tags
}

module "network" {
  source = "./modules/network"

  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  vnet_cidr           = var.vnet_cidr
  tags                = local.tags
}

module "aks" {
  source = "./modules/aks"

  name                       = local.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  kubernetes_version         = var.kubernetes_version
  node_subnet_id             = module.network.node_subnet_id
  system_node_min            = var.system_node_min
  system_node_max            = var.system_node_max
  system_node_size           = var.system_node_size
  user_node_min              = var.user_node_min
  user_node_max              = var.user_node_max
  user_node_size             = var.user_node_size
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  prometheus_workspace_id    = module.monitoring.prometheus_workspace_id
  admin_group_object_ids     = var.admin_group_object_ids
  tags                       = local.tags
}
