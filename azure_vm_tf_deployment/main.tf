#Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 0.14.9"
}
#Azure provider with spn configurations
provider "azurerm" {
  features {}

  subscription_id             = var.subscription_id
  client_id                   = var.client_id
  client_secret               = var.client_secret
  tenant_id                   = var.tenant_id
}

#Create azure resource group
resource "azurerm_resource_group" "rg" {
  name     = "RG-${var.customer_name}"
  location = var.location
  tags = {
    "environment" = var.environment
  }
}
output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

#Create azure virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.customer_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = var.environment
  }
}

#Creat subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.customer_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.customer_name}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "APP_INB"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}
#Create public IPs
resource "azurerm_public_ip" "pip" {
  name                = "${var.customer_name}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"

  tags = {
    environment = var.environment
  }
}

#Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.customer_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.customer_name}-ip-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

#Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "attachnsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#Create SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.customer_name}-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_V3"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_username = "adminuser"


  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = var.environment
  }
}

#copy scripts folder content to remote server and exec
resource "null_resource" "provisioner_app" {

  connection {
    type  = "ssh"
    host  = azurerm_public_ip.pip.ip_address
    user  = "adminuser"
    private_key = tls_private_key.ssh.private_key_pem 
    agent = true
    

  }

  // copy scripts to the server tmp location
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/"
  }

  // change permissions to executable and run
  provisioner "remote-exec" {
    inline = [

      "sudo chmod +x /tmp/deploy.sh",
      "sudo sh /tmp/deploy.sh"
    ]
  }
}