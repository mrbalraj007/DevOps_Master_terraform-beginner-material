variable "location" {
  description = "Azure region to deploy into"
  default     = "EastUS"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "rg-hyperv-migration"
}

variable "admin_username" {
  description = "Admin username for VMs"
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Strong password (sensitive)"
  sensitive   = true
  default     = "test@123"
}
