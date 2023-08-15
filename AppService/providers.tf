provider "azurerm" {
  features {}
}


terraform {
  backend "azurerm" {
    resource_group_name  = "backend-resource-group"
    storage_account_name = "stgaccount456"
    container_name       = "tfstate"
    key                  = "terraform-test.tfstate"
  }
}
