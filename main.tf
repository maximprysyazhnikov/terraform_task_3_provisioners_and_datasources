#####################################
# Local Nginx page
#####################################
locals {
  nginx_index_html = <<-HTML
  <!doctype html>
  <html>
    <head>
      <meta charset="utf-8">
      <title>Nginx on Azure</title>
    </head>
    <body style="font-family: Arial;">
      <h1>✅ Nginx працює!</h1>
      <p>VM: ${var.vm_name}</p>
      <p>Resource Group: ${var.resource_group_name}</p>
    </body>
  </html>
  HTML
}

#####################################
# Virtual Network
#####################################
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-task-3"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
}

#####################################
# Subnet
#####################################
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-task-3"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

#####################################
# Public IP
#####################################
resource "azurerm_public_ip" "pip" {
  name                = "pip-task-3"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#####################################
# Network Security Group
#####################################
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-task-3"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#####################################
# Network Interface
#####################################
resource "azurerm_network_interface" "nic" {
  name                = "nic-task-3"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#####################################
# Linux Virtual Machine
#####################################
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  size                = "Standard_DS1_v2"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  #####################################
  # File provisioner
  #####################################
  provisioner "file" {
    content     = local.nginx_index_html
    destination = "/tmp/index.html"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = azurerm_public_ip.pip.ip_address
    }
  }

  #####################################
  # Remote exec provisioner
  #####################################
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx",
      "sudo mv /tmp/index.html /var/www/html/index.html",
      "sudo systemctl enable nginx",
      "sudo systemctl restart nginx"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file(var.ssh_private_key_path)
      host        = azurerm_public_ip.pip.ip_address
    }
  }
}


#####################################
# Outputs
#####################################
output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "nginx_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}"
}
