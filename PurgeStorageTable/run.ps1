# Input bindings are passed in via param block.
param($Timer)

$StorageAccountResourceGroup = $env:StorageAccountResourceGroup  #Resource Group Name
$StorageAccountName = $env:StorageAccountName             #Storage Account Name
$AllVmStartChangesTableName =  $env:AllVmStartChangesTableName #Saves all VM restart changes

$storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup
$AllVmStartChangesTable = Get-AzStorageTable -Context $storageAccount.Context -Name $AllVmStartChangesTableName

Get-AzTableRow -Table $AllVmStartChangesTable.CloudTable | Remove-AzTableRow -Table $AllVmStartChangesTable.CloudTable