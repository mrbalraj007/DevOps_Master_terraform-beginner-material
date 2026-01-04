#############################################
# Main Orchestration File
# Azure Hyper-V Migration Lab
#############################################

locals {
  common_tags = {
    Environment = "Migration-Lab"
    Owner       = "Cloud-Team"
    Platform    = "Azure"
    ManagedBy   = "Terraform"
  }
  install_script_b64 = base64encode(file("${path.module}/scripts/install-hyperv.ps1"))
}

#############################################
# Apply Tags to Resource Group
#############################################

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

#############################################
# Network Components
#############################################

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-landing-zone"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-workloads"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-hyperv"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#############################################
# Public IP & NIC
#############################################

resource "azurerm_public_ip" "hyperv_pip" {
  name                = "pip-hyperv-host"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "hyperv_nic" {
  name                = "nic-hyperv-host"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hyperv_pip.id
  }
}

# Add: dedicated NIC for SQL VM (no public IP)
resource "azurerm_network_interface" "sql_nic" {
  name                = "nic-sql-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    # intentionally no public_ip_address_id
  }
}

#############################################
# Hyper-V Host VM (Nested Virtualization)
#############################################

resource "azurerm_windows_virtual_machine" "hyperv_host" {
  name                = "vm-hyperv-host"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_D4s_v3" # switch to DSv3 family to avoid DSv5 quota issues
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.hyperv_nic.id
  ]

  os_disk {
    name                 = "osdisk-hyperv"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }
}

#############################################
# Hyper-V Installation Script
#############################################

resource "azurerm_virtual_machine_extension" "hyperv_install" {
  name                 = "install-hyperv"
  virtual_machine_id   = azurerm_windows_virtual_machine.hyperv_host.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Bypass -Command \"Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart\""
}
SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.hyperv_host
  ]
}

# Add: post-install extension — uploads and runs local scripts/install-hyperv.ps1 after hyperv_install completes
resource "azurerm_virtual_machine_extension" "hyperv_postinstall" {
  name                 = "postinstall-hyperv"
  virtual_machine_id   = azurerm_windows_virtual_machine.hyperv_host.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Bypass -Command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.install_script_b64}')) | Set-Content -Path 'C:\\Temp\\install-hyperv.ps1' -Encoding UTF8; & 'C:\\Temp\\install-hyperv.ps1'\""
}
SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.hyperv_install
  ]
}

#############################################
# SQL Server VM (Migration Target)
#############################################

resource "azurerm_windows_virtual_machine" "sql_vm" {
  name                = "vm-sql-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_D2s_v3" # use DSv3 family or another family you have quota for
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.sql_nic.id
  ]

  os_disk {
    name                 = "osdisk-sql"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }
}
