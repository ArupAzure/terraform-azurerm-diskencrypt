#AzureRM Variables
variable "node_count" {}
variable "vm_name" {}
variable "ddisk_mount_required" {}
variable "nbof_data_disk" {default = ""}

variable "vm_sku_type" {}
variable "osdisk_type" {}

variable "vm_keyvault_name" {}
variable "vm_keyvault_rg_name" {}
variable "disk_encryption_required" {}
variable "mddisk_type" {}
variable "mddisk_size" {}
variable "data_disk_required" {default = ""}
variable "location_name" {}
variable "vm_rg_name" {}
variable "nw_rg_name" {}
variable "vnet_name" {}
variable "subnet_name" {}
variable "keyvault_rg_name" {}
variable "keyvault_name" {}
variable "key_name" {}

variable "tags" {
  default = {
    "Power Off" = "N"
  }
}
variable "diag_storage_name" {}
