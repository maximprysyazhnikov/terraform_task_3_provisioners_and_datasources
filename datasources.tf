data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

#####################################
# Datasources (task requirement)
#####################################
data "azurerm_virtual_network" "vnet" {
  name                = azurerm_virtual_network.vnet.name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  name                 = azurerm_subnet.subnet.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_network_interface" "nic" {
  name                = azurerm_network_interface.nic.name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_virtual_machine" "vm" {
  name                = azurerm_linux_virtual_machine.vm.name
  resource_group_name = data.azurerm_resource_group.rg.name
}