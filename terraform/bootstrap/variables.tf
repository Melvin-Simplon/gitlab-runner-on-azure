variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "argocd_chart_version" {
  type    = string
  default = "10.9.6"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.6"
}
