# Input bindings are passed in via param block.
param($Timer)

$Query = @"
resources
| where type == "microsoft.storage/storageaccounts" | project name, type, kind
"@
$StorageAccountResourceGroup = "sqlbrains_group"
$StorageAccountName = "vmrestartdata"
$StorageTableName = "restartdata"
$StorageTablePartitionKey = 'VMPartition'
$PropertyToCompare = "name"

$Result = Search-AzGraph -Query $Query

$storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup
$storageTable = Get-AzStorageTable -Context $storageAccount.Context -Name $StorageTableName

#$OldResult = Get-AzTableRowAll -Table $storageTable.CloudTable

#$ComparedObject = Compare-Object -ReferenceObject $OldResult -DifferenceObject $Result -Property $PropertyToCompare

#$OldResult | Remove-AzTableRow -Table $storageTable.CloudTable

foreach($element in $Result)
{
    $hashtable = @{}
    foreach( $property in $element.psobject.properties.name )
    {
        $hashtable[$property] = $element.$property
    }
    Add-AzTableRow -Table $storageTable.CloudTable -property $hashtable -partitionKey $StorageTablePartitionKey -rowkey ([guid]::NewGuid().tostring())
}

$Body = @{data = (($Result | ConvertTo-Html -Fragment) -join "")} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri $env:LOGIC_APP_URL -Body $Body -ContentType "application/json"






