variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

# Globally unique name, 3 to 24 lowercase letters and digits.
variable "backup_storage_account" {
  type = string
}
