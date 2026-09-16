variable "prefix" {
  description = "Short name prefix applied to all resources (lowercase, 3-8 chars)."
  type        = string
  default     = "akssre"

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.prefix))
    error_message = "prefix must be 3-8 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "centralus"
}

variable "environment" {
  description = "Environment name used in tags and resource naming."
  type        = string
  default     = "demo"
}

variable "vnet_cidr" {
  description = "Address space for the platform VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "system_node_count" {
  description = "Node count for the system node pool."
  type        = number
  default     = 1
}

variable "system_node_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "user_node_min" {
  description = "Minimum nodes for the autoscaling user node pool."
  type        = number
  default     = 1
}

variable "user_node_max" {
  description = "Maximum nodes for the autoscaling user node pool."
  type        = number
  default     = 4
}

variable "user_node_size" {
  description = "VM size for the user node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Leave null to use the region default."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via Azure RBAC."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
