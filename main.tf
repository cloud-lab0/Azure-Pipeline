# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

locals {
  prefix = "DEMO-PPL-"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myResourceGroup" {
    name     = "${local.prefix}resourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myVirtualNetwork" {
    name                = "${local.prefix}myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myResourceGroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "mySubnet" {
    name                 = "${local.prefix}mySubnet"
    resource_group_name  = azurerm_resource_group.myResourceGroup.name
    virtual_network_name = azurerm_virtual_network.myVirtualNetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myPublicIP" {
    name                         = "${local.prefix}myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myResourceGroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "mySecurityGroup" {
    name                = "${local.prefix}myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myResourceGroup.name

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
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myNetworkInterface" {
    name                      = "${local.prefix}myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myResourceGroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.mySubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myPublicIP.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "SGconnectNI" {
    network_interface_id      = azurerm_network_interface.myNetworkInterface.id
    network_security_group_id = azurerm_network_security_group.mySecurityGroup.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myResourceGroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myResourceGroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myVirtualMachine" {
    name                  = "${local.prefix}myVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myResourceGroup.name
    network_interface_ids = [azurerm_network_interface.myNetworkInterface.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "${local.prefix}myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "${local.prefix}myvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = file("~/.ssh/id_rsa.pub")
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}