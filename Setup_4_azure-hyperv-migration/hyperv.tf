# Hyper-V VM, public IP and NIC resources moved/kept in main.tf to avoid duplicates.
# ...no Terraform resources in this file...

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

resource "azurerm_windows_virtual_machine" "hyperv_host" {
  name                = "vm-hyperv-host"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_D4s_v3"
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
    sku       = "2025-datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "hyperv_install" {
  name                 = "setup-hyperv"
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
    azurerm_windows_virtual_machine.hyperv_host
  ]
}
