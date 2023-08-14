resource "azurerm_resource_group" "linuxrg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "linuxvnet" {
  name                = "linuxmyVNet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.linuxrg]
}

resource "azurerm_subnet" "linuxsubnet" {
  name                 = "linuxmySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.linuxvnet.name
  address_prefixes     = ["10.1.1.0/24"]
  depends_on = [azurerm_virtual_network.linuxvnet]
}

resource "azurerm_subnet" "linux_appgw_subnet" {
  name                 = "linux-appgw-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.linuxvnet.name
  address_prefixes     = ["10.1.2.0/24"]
  depends_on = [azurerm_virtual_network.linuxvnet]
}

resource "azurerm_linux_virtual_machine" "linuxvm" {
  name                = "linuxVM"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  disable_password_authentication = false

   depends_on          = [azurerm_network_interface.linuxnic]

  network_interface_ids = [azurerm_network_interface.linuxnic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

   custom_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y apache2
              sudo ufw allow 80/tcp
              sudo ufw --force enable
              echo '<!doctype html><html><body><h1>Hola Mundo</h1></body></html>' | sudo tee /var/www/html/index.html
              EOF
  )
}

resource "azurerm_network_interface" "linuxnic" {
  name                = "myNIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.linuxsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linuxpip.id 
  }
  depends_on = [azurerm_subnet.linuxsubnet, azurerm_public_ip.linuxpip] 
}

resource "azurerm_public_ip" "linuxpip" {
  name                = "linuxVMPublicIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [azurerm_resource_group.linuxrg]
}

resource "azurerm_public_ip" "linuxapgw_pip" {
  name                = "linuxaapgwPublicIP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.linuxrg]
}

resource "azurerm_application_gateway" "linuxappgw" {
  name                = var.app_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

    depends_on = [azurerm_subnet.linux_appgw_subnet]


  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.linux_appgw_subnet.id
  }

  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "my-frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.linuxapgw_pip.id
  }

  backend_address_pool {
    name = "backend-address-pool"
    fqdns = [azurerm_network_interface.linuxnic.ip_configuration[0].private_ip_address]  
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "my-frontend-ip-configuration"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule"
    rule_type                  = "Basic"
    http_listener_name         = "listener"
    backend_address_pool_name  = "backend-address-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100 
  }
}
