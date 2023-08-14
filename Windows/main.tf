resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "testvnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "subnet" {
  name                 = "testsubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]

}

resource "azurerm_public_ip" "publicip" {
  name                = "mypublicip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_public_ip" "vm_publicip" {
  name                = "vmpublicip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_network_interface" "my_nic" {
  name                = "mynic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "myconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_publicip.id
  }
  depends_on = [azurerm_subnet.subnet]
}

locals {
  vm_private_ip     = azurerm_network_interface.my_nic.ip_configuration[0].private_ip_address
  powershell_script = <<-EOT
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    $content = @"
    <html>
    <body>
        <h1>Hola Mundo</h1>
    </body>
    </html>
    "@
    $content | Out-File -FilePath "C:\inetpub\wwwroot\index.html"
  EOT

  encoded_script = base64encode(local.powershell_script)
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "vmtest"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.my_nic.id]
  size                  = var.size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  custom_data           = base64encode(<<EOT
          # Instalar IIS
        Install-WindowsFeature -name Web-Server -IncludeManagementTools

        # Eliminar el sitio web predeterminado
        Remove-Website -Name 'Default Web Site'

        # Crear un nuevo sitio web para "Hola Mundo"
        New-Item -Path 'C:\inetpub\wwwroot\helloworld' -Type Directory -Force
        Add-Content -Path 'C:\inetpub\wwwroot\helloworld\index.html' -Value '<h1>Hola Mundo</h1>'

        New-Website -Name 'HelloWorldSite' -PhysicalPath 'C:\inetpub\wwwroot\helloworld' -Port 80

        # Habilitar el tráfico HTTP a través del firewall
        New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
        EOT
  )

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.image_version
  }

  os_disk {
    name                 = "osdisk"
    caching              = var.caching
    storage_account_type = var.storage_account_type
  }

  tags = {
    environment = "test"
  }
  depends_on = [azurerm_network_interface.my_nic]
}


//NSG

resource "azurerm_network_security_group" "nsg" {
  name                = "myNSG"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nicnsg" {
  network_interface_id      = azurerm_network_interface.my_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


//APP GATEWAY


resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}



resource "azurerm_application_gateway" "ag" {
  name                = "testappgateway"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1

  }
  depends_on = [azurerm_subnet.appgw_subnet]


  /*gateway_configuration {
    subnet_id = azurerm_subnet.appgw_subnet.id
     }*/

  gateway_ip_configuration {
    name      = "myipconfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }


  frontend_port {
    name = var.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = var.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.publicip.id
  }

  backend_address_pool {
    name         = var.backend_address_pool_name
    fqdns        = [] # Si no tienes FQDNs, simplemente coloca una lista vacía
    ip_addresses = [local.vm_private_ip]
  }

  backend_http_settings {
    name                  = var.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = var.listener_name
    frontend_ip_configuration_name = var.frontend_ip_configuration_name
    frontend_port_name             = var.frontend_port_name
    protocol                       = "Http"

  }

  request_routing_rule {
    name                       = var.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = var.listener_name
    backend_address_pool_name  = var.backend_address_pool_name
    backend_http_settings_name = var.http_setting_name
    priority                   = 1
  }


  tags = {
    environment = "test"
  }
}

