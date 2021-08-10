###############################################################################
# Developed by Tunga Mallikarjuna Reddy
###############################################################################

# Generate random text for a unique Public IP name
resource "random_id" "randomId" {
    byte_length = 5
}
# Read and Load Vnet Info
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.nw_rg_name
}
# Read and Load Subnet Info
data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.nw_rg_name
}
# Read and Load Keyvault Info
data "azurerm_key_vault" "kv" {
  count               = var.disk_encryption_required ? 1 :0
  name                = var.keyvault_name
  resource_group_name = var.keyvault_rg_name
}
# Read and Load Keyvault KeK Info
data "azurerm_key_vault_key" "key" {
  count               = var.disk_encryption_required ? 1 :0
  name                = var.key_name
  key_vault_id        = data.azurerm_key_vault.kv[0].id
}
# Create public IPs
resource "azurerm_public_ip" "public_ip" {
    name                         = "Arjun${random_id.randomId.hex}"
    location                     = var.location_name
    resource_group_name          = var.vm_rg_name
    allocation_method            = "Dynamic"

    tags = {
        environment = "MSFT Reactor"
    }
}
# Create network interface
resource "azurerm_network_interface" "private_nic" {
  name                = "${var.vm_name}-nic01"  
  location            = var.location_name
  resource_group_name = var.vm_rg_name

  ip_configuration {
    name                          = "${var.vm_name}-ip1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"    
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
  tags = {
        environment = "MSFT Reactor"
  }
}

# Create Virtual Machine with RedHat MarketPlace Image
resource "azurerm_virtual_machine" "vm" {  
  name                  = var.vm_name
  location              = var.location_name  
  resource_group_name   = var.vm_rg_name
  network_interface_ids = [azurerm_network_interface.private_nic.id]
  vm_size               = var.vm_sku_type

  storage_image_reference {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "7_9"
      version   = "latest"
  }
  storage_os_disk {
    name              = "${var.vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.osdisk_type    
  }
  dynamic storage_data_disk {
    for_each = range(var.nbof_data_disk)
    content {
      name              = "${var.vm_name}-ddisk0${storage_data_disk.value +1}"      
      create_option     = "Empty"
      lun               = storage_data_disk.value
      disk_size_gb      = var.mddisk_size
      managed_disk_type = var.mddisk_type      
    }
  }  
  os_profile {
    computer_name  = var.vm_name
    admin_username = "rheladmin"
    admin_password = "Passw0rd!123"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  boot_diagnostics {
      enabled     = "true"
      storage_uri = var.diag_storage_name
  }
  tags = var.tags
}
# Run Custom Script Post VM Creation
resource "azurerm_virtual_machine_extension" "CustomScript" {
  count                         = var.ddisk_mount_required == "true" ? 1 : 0
  name                          = "customScript"
  virtual_machine_id            = azurerm_virtual_machine.vm.id
  publisher                     = "Microsoft.Azure.Extensions"
  type                          = "CustomScript"
  type_handler_version          = "2.1"

   settings = <<SETTINGS
     {
         "skipDos2Unix":true
     }
 SETTINGS
   protected_settings = <<PROTECTED_SETTINGS
     {
        "commandToExecute": "bash prepare_disks.sh",
        "fileUris": ["https://vmtfbackend01.blob.core.windows.net/scripts/prepare_disks.sh"]
     }
 PROTECTED_SETTINGS
 
 depends_on = [azurerm_virtual_machine.vm] 
}
# Wait 3 Mins to Custom Script process cool down
resource "null_resource" "sleep_3M" {
  provisioner "local-exec" {
    command = "sleep 180"
  }
  depends_on = [azurerm_virtual_machine_extension.CustomScript]
}
# Run Azure Disk Encryption Post VM Custom Script Execution
resource "azurerm_virtual_machine_extension" "RhelAde" {
  count                        = var.disk_encryption_required == "true" ? 1 : 0
  name                         = "LinuxDiskEncryption"
  virtual_machine_id           = azurerm_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Security"
  type                         = "AzureDiskEncryptionForLinux"
  type_handler_version         = "1.2"
  auto_upgrade_minor_version   = true

  settings = <<SETTINGS
    {
        "EncryptionOperation": "EnableEncryption",
        "KeyVaultURL": "${data.azurerm_key_vault.kv[0].vault_uri}",
        "KeyVaultResourceId": "${data.azurerm_key_vault.kv[0].id}",
        "KeyEncryptionKeyURL": "${data.azurerm_key_vault_key.key[0].id}",
        "KekVaultResourceId": "${data.azurerm_key_vault.kv[0].id}",
        "KeyEncryptionAlgorithm": "RSA-OAEP",
        "VolumeType": "ALL"
    }
SETTINGS

  depends_on = [null_resource.sleep_3M]
}
