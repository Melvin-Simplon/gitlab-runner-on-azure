variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

# Two nodes, because the DSv3 vCPU quota is shared by the whole class.
variable "node_count" {
  type    = number
  default = 2
}
