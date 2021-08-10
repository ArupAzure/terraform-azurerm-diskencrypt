###############################################################################
# Developed by Tunga Mallikarjuna Reddy
###############################################################################

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.nw_rg_name
}
data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.nw_rg_name
}
data "azurerm_key_vault" "kv" {
  count               = var.disk_encryption_required ? 1 :0
  name                = var.keyvault_name
  resource_group_name = var.keyvault_rg_name
}
data "azurerm_key_vault_key" "key" {
  count               = var.disk_encryption_required ? 1 :0
  name                = var.key_name
  key_vault_id        = data.azurerm_key_vault.kv[0].id
}
resource "azurerm_network_interface" "private_nic" {
  name                = "${var.vm_name}-nic01"  
  location            = var.location_name
  resource_group_name = var.vm_rg_name

  ip_configuration {
    name                          = "${var.vm_name}-ip1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = var.ip_type
    private_ip_address            = var.ip_addr
    public_ip_address_id          = var.public_ip_required == "true" ? azurerm_public_ip.pip[count.index].id : ""
  }
  enable_accelerated_networking = var.enable_accelerated_nw
    
  tags = merge(var.tags, {"SubNet" : var.subnet_name})
}

resource "azurerm_virtual_machine" "vm" {
  count                 = var.node_count
  name                  = "${local.server_name}0${count.index + 1}"
  location              = var.location_name
  zones                 = [var.zones[count.index % length(var.zones)]]
  resource_group_name   = var.vm_rg_name
  network_interface_ids = [element(azurerm_network_interface.private_nic.*.id, count.index)]
  vm_size               = var.vm_sku_type
  license_type          = var.win_license_type != "" ? var.win_license_type : null
  
  delete_os_disk_on_termination    = var.delete_os_disk
  delete_data_disks_on_termination = var.delete_data_disks

  storage_image_reference {
    id        = var.os_cs_img_required == "true" ? var.os_cs_img_id : ""
    publisher = var.os_cs_img_required == "true" ? "" : var.os_mk_img_publisher
    offer     = var.os_cs_img_required == "true" ? "" : var.os_mk_img_offer
    sku       = var.os_cs_img_required == "true" ? "" : var.os_mk_img_sku
    version   = var.os_cs_img_required == "true" ? "" : var.os_mk_img_version
  }
  boot_diagnostics {
    enabled     = "true"
    storage_uri = var.diag_storage_name
  }
  storage_os_disk {
    name              = "${local.server_name}0${count.index + 1}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.osdisk_type
    #disk_size_gb      = var.osdisk_size
  }
  dynamic storage_data_disk {
    for_each = range(var.nbof_data_disk)
    content {
      name              = "${local.server_name}0${count.index + 1}-ddisk0${storage_data_disk.value +1}"
      //caching           = "None"
      create_option     = "Empty"
      lun               = storage_data_disk.value
      disk_size_gb      = var.mddisk_size
      managed_disk_type = var.mddisk_type
      //write_accelerator_enabled = var.mddisk_accelerator_enabled
    }
  }  
  os_profile {
    computer_name  = "${local.server_name}0${count.index + 1}"
    admin_username = data.azurerm_key_vault_secret.secusr.value
    admin_password = data.azurerm_key_vault_secret.secpass.value
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }  
  provisioner "local-exec" {
    command = "echo ${self.name}>> ./hosts.txt"
  }
  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "LvmCustomScript" {
  count                         = var.ddisk_mount_required == "true" ? var.node_count : 0
  name                          = "customScript"
  virtual_machine_id            = element(azurerm_virtual_machine.vm.*.id, count.index + 1)
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
        "commandToExecute": "bash prepare_lvmdisks.sh",
        "fileUris": ["https://vmtfbackend01.blob.core.windows.net/scripts/prepare_lvmdisks.sh"]
     }
 PROTECTED_SETTINGS
 
 depends_on = [azurerm_virtual_machine.vm] 
}

resource "azurerm_virtual_machine_extension" "nw-watcher" {
  count                        = var.nw_watcher_required == "true" ? var.node_count : 0
  name                         = "NetworkWatcher"
  virtual_machine_id           = element(azurerm_virtual_machine.vm.*.id, count.index + 1)
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = var.nwwType
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  depends_on = [azurerm_virtual_machine.vm]
}
resource "azurerm_virtual_machine_extension" "RhelAdeLvm" {
  count                        = var.disk_encryption_required == "true" ? var.node_count : 0
  name                         = "LinuxDiskEncryption"
  virtual_machine_id           = element(azurerm_virtual_machine.vm.*.id, count.index + 1)
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
        "VolumeType": "DATA"
    }
SETTINGS

  depends_on = [azurerm_virtual_machine_extension.LvmCustomScript]
}
resource "azurerm_virtual_machine_extension" "log_analytics" {
  count                         = var.enable_log_analytics == "true" ? var.node_count : 0
  name                          = "LogAnalytics"
  virtual_machine_id            = element(azurerm_virtual_machine.vm.*.id, count.index + 1)
  publisher                     = "Microsoft.EnterpriseCloud.Monitoring"
  type                          = var.agntType
  type_handler_version          = "1.0"

   settings = <<SETTINGS
     {
         "workspaceId": ""
     }
 SETTINGS
   protected_settings = <<PROTECTED_SETTINGS
     {
         "workspaceKey": ""
     }
 PROTECTED_SETTINGS
 
  depends_on = [azurerm_virtual_machine_extension.nw-watcher]
}
resource "null_resource" "rg" {
  provisioner "local-exec" {
    command = "sed -i s/vmrg/${var.vm_rg_name}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/vmlocation/${var.location_name}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/staticip/${var.static_ip_required}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/keyvaultrg/${var.keyvault_rg_name}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/VaultValue/${var.keyvault_name}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/KeyValue/${var.key_name}/g ./scripts/VMExtensions.ps1"
  }
  provisioner "local-exec" {
    command = "sed -i s/diskencryption/${var.der}/g ./scripts/VMExtensions.ps1"
  }
}
