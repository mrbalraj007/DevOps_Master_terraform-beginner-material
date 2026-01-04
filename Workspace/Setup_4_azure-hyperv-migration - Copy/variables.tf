variable "location" {
  description = "Azure region to deploy into"
}

variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "admin_username" {
  description = "Admin username for VMs"
}

variable "admin_password" {
  description = "Strong password (sensitive)"
  sensitive   = true
}
