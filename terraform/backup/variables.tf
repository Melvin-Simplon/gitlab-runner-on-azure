variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

# Unique in Azure: 3 to 24 lowercase letters and digits.
variable "backup_storage_account" {
  type = string
}
