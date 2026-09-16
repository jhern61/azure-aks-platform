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

variable "system_node_count" {
  type    = number
  default = 1
}

variable "system_node_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "user_node_min" {
  type    = number
  default = 1
}

variable "user_node_max" {
  type    = number
  default = 4
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
