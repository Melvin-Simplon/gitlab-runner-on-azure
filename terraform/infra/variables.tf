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

# Fixed at 2: the DSv3 quota (10 vCPU) is shared by the whole class, 4 are already used elsewhere.
variable "node_count" {
  type    = number
  default = 2
}
