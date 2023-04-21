param($Timer)

# Set Up the query for Resource graph
$Query = @"
resources
| where type == "microsoft.storage/storageaccounts" | project name, type, kind
"@

$StorageAccountResourceGroup = "sqlbrains_group"    #Resource Group Name
$StorageAccountName = "vmrestartdata"               #Storage Account Name
$StorageTableName = "restartdata"                   #Storage Table Name
$StorageTablePartitionKey = 'VMPartition'           #Partion Name (Can be anything)

$Result = Search-AzGraph -Query $Query

$storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup
$storageTable = Get-AzStorageTable -Context $storageAccount.Context -Name $StorageTableName

Get-AzTableRow -Table $storageTable.CloudTable | Remove-AzTableRow -Table $storageTable.CloudTable

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






