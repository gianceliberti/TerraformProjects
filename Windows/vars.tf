// VIRTUAL MACHINE VARIABLES

variable "resource_group_name" {
  type    = string
  default = "resourcegrouptest"
}
variable "location" {
  type    = string
  default = "West Europe"
}
variable "name" {
  type    = string
  default = "otro nombre"
}
variable "size" {
  type    = string
  default = "Standard_B1s"
}
variable "admin_username" {
  type    = string
  default = "juanchotalarga"

}
variable "admin_password" {
  type    = string
  default = "P@ssw0rd123!"
}
variable "nic_id" {
  type    = string
  default = "nicid"
}
variable "caching" {
  type    = string
  default = "ReadWrite"
}
variable "storage_account_type" {
  type    = string
  default = "Standard_LRS"
}
variable "source_image_reference" {
  type = map(any)
  default = {

  }
}
variable "publisher" {
  type    = string
  default = "MicrosoftWindowsServer"
}
variable "offer" {
  type    = string
  default = "WindowsServer"
}
variable "sku" {
  type    = string
  default = "2016-Datacenter"
}
variable "image_version" {
  type    = string
  default = "latest"
}
variable "generation" {
  type    = number
  default = 1
}



//APP GATEWAY VARIABLES

variable "backend_address_pool_name" {
  default = "myBackendPool"
}

variable "frontend_port_name" {
  default = "myFrontendPort"
}

variable "frontend_ip_configuration_name" {
  default = "myAGIPConfig"
}

variable "http_setting_name" {
  default = "myHTTPsetting"
}

variable "listener_name" {
  default = "myListener"
}

variable "request_routing_rule_name" {
  default = "myRoutingRule"
}

variable "redirect_configuration_name" {
  default = "myRedirectConfig"
}