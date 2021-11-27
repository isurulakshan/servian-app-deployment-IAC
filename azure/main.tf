#Configure the Azure Provider
terraform{
    required_providers{
        azurerm =   {
            source  =  "hashicorp/azurerm"
        }
    }
    required_version =  ">= 0.14.9"
}

provider "azurerm" {
  features{}
}

#Create azure resource group
resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
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
  name                = "VNET-APP-DEP"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "PRD"
  }
}

#Creat subnet
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
    name                = "app-dep-nsg"
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

    tags = {
        environment = "PRD"
    }
}
#Create public IPs
resource "azurerm_public_ip" "pip" {
    name                         = "app-dep-pip"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.rg.name
    allocation_method            = "Static"

    tags = {
        environment = "PRD"
    }
}

#Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "app-dep-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "app-dep-ip"
    subnet_id                     =  azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

#Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "attachnsg" {
    network_interface_id      = azurerm_network_interface.nic.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

#Create (and display) an SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.ssh.private_key_pem 
    sensitive = true
}
#Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "app-dep-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_username      = "adminuser"
  disable_password_authentication = true


   admin_ssh_key {
        username       = "adminuser"
        public_key     = tls_private_key.ssh.public_key_openssh
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "PRD"
  }
}

# Create virtual machine extention and exec script
resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = "app-dep-vmext"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(file(var.deployment_script))}"
    }
SETTINGS


  tags = {
    environment = "PRD"
  }
}
