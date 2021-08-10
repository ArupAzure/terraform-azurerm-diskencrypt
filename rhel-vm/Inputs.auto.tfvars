vm_name     = "RHELVMMSFT"
vm_rg_name  = "common-rg"
nw_rg_name  = "network-rg"
vnet_name   = "corp-vnet-01"
subnet_name = "WinSubnet01"

location_name             = "westeurope"
disk_encryption_required  = "true"
nbof_data_disk            = "1"
ddisk_mount_required      = "true"

vm_sku_type = "Standard_D2S_V3"
osdisk_type = "Premium_LRS"
mddisk_type = "Premium_LRS"
mddisk_size = "16"

keyvault_rg_name = "keyvault-rg"
keyvault_name    = "weuskv01"
key_name         = "WinVMKvKek01"

diag_storage_name = "https://vmbootdaigsa01.blob.core.windows.net/"

tags = {  
  "CostCenter"    = "Personal"
  "Dept"          = "Community"
  "Maintainer"    = "Tunga Malli"
  "Power Off"     = "Y"
}
