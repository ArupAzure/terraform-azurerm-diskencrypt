provider "azurerm" {
  features {}
  //subscription_id = "12345678-1234-1234-1234-12345678"
}

/*terraform {
  backend "azurerm" {
    //subscription_id      = "12345678-1234-1234-1234-12345678"
    resource_group_name  = "terrafrom-rg"
    storage_account_name = "vmtfbackend01"
    container_name       = "abrtfkeystore"
    key                  = "windows-vm-key"
  }
}*/
