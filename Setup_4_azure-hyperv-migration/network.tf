# Network resources consolidated into main.tf to avoid duplicate resource declarations.

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

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
