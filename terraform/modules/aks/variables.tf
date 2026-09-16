variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "node_subnet_id" {
  type = string
}

variable "system_node_min" {
  description = "Minimum nodes for the autoscaling system node pool. Must be >= 2 for HA."
  type        = number
  default     = 2

  validation {
    condition     = var.system_node_min >= 1
    error_message = "system_node_min must be at least 1."
  }
}

variable "system_node_max" {
  description = "Maximum nodes for the autoscaling system node pool."
  type        = number
  default     = 3

  validation {
    condition     = var.system_node_max >= 1
    error_message = "system_node_max must be at least 1."
  }
}

variable "system_node_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "user_node_min" {
  description = "Minimum nodes for the autoscaling user node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.user_node_min >= 1
    error_message = "user_node_min must be at least 1."
  }
}

variable "user_node_max" {
  description = "Maximum nodes for the autoscaling user node pool."
  type        = number
  default     = 4

  validation {
    condition     = var.user_node_max >= 2
    error_message = "user_node_max must be at least 2."
  }
}

variable "user_node_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "prometheus_workspace_id" {
  type = string
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
