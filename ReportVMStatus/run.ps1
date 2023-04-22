param($Timer)

# Set Up the query for Resource graph
$Query = @"
resources
| where type == "microsoft.storage/storageaccounts" | project id, name, type, kind
"@

$StorageAccountResourceGroup = "sqlbrains_group"    #Resource Group Name
$StorageAccountName = "vmrestartdata"               #Storage Account Name
$StorageTableName = "restartdata"                   #Storage Table Name
$StorageTablePartitionKey = 'VMPartition'           #Partion Name (Can be anything)
$PropertyToCompare = "kind"
$PrimaryPropertyKey = "id"

$Result = Search-AzGraph -Query $Query

$storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup
$storageTable = Get-AzStorageTable -Context $storageAccount.Context -Name $StorageTableName

$UpdatedResult = @()
foreach($element in $Result){
    $oldElement = Get-AzTableRow -Table $storageTable.CloudTable `
        -CustomFilter "$($PrimaryPropertyKey) eq '$($element.$PrimaryPropertyKey)'" -Top 1

    if($oldElement.$PropertyToCompare -ne $element.$PropertyToCompare)
    {
        $UpdatedResult += $element
    }
}

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

$Body = @{data = (($UpdatedResult | ConvertTo-Html -Fragment) -join "")} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri $env:LOGIC_APP_URL -Body $Body -ContentType "application/json"






