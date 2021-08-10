$vmName = "vmname"
$rgName = "vmrg"
$location = "vmlocation"
$keyrgName = "keyvaultrg"
$keyVaultName = "VaultName"
$keyVaultKey = "KeyName"
$den = "true" #[true/false]

$KeyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyrgName;
$VaultUrl = $keyVault.VaultUri; $VaultId = $keyVault.ResourceId;
$KeyUrl = (Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyVaultKey).Key.kid;

if ($den -eq "true") {
    Write-Host "--------- Enabling--Disk-Encryption--for-VM: $vmName" }
    Set-AzureRmVMDiskEncryptionExtension -Name "DiskEncryption" -ResourceGroupName $rgName -VMName $vmName -DiskEncryptionKeyVaultUrl $VaultUrl -DiskEncryptionKeyVaultId $VaultId -KeyEncryptionKeyUrl $KeyUrl -KeyEncryptionKeyVaultId $VaultId -VolumeType 'ALL' -skipVmBackup -Force
    Write-Host "--------- ------------------- ---------- ------------"
}else {
    Write-Host "--------- Enabling--Disk-Encryption--for-VM: $vmName | Not Requested"
    Write-Host "--------- ------------------- ---------- ------------"
}

Start-Sleep -s 120;

if($den -eq "true") {
    Write-Host "--------- Disk-Encryption--Provisioning--for-VM: $vm";
    Get-AzureRmVMDiskEncryptionStatus -ResourceGroupName $rgName -VMName $vmName -Name "DiskEncryption";
    Write-Host "--------- ------------------- ---------- ------------"
}
