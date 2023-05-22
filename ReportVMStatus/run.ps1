# Input bindings are passed in via param block.
param($Timer)

# Set Up the query for Resource graph
$Query = @"
resources 
| where type =~ 'microsoft.compute/virtualmachines'
| extend VM_SKU=properties.hardwareProfile.vmSize
| project VM_name = name, resourceId = tolower(id),VM_SKU
| join (healthresources 
   | where type =~ 'microsoft.resourcehealth/resourceannotations'
   | project resourceId = tolower(tostring(properties.targetResourceId)),  Region = location, resourceGroup, RebootTime = properties.occurredTime, Reason = properties.reason, category=properties.category, context=properties.context
) on resourceId
| project VM_name, resourceId, VM_SKU, RebootTime, Reason, resourceGroup, context, category
"@

Write-host $Query

$StorageAccountResourceGroup = $env:StorageAccountResourceGroup  #Resource Group Name
$StorageAccountName = $env:StorageAccountName             #Storage Account Name
$StorageTableName = $env:StorageTableName                   #Storage Table Name
$StorageTablePartitionKey = $env:StorageTablePartitionKey   #Partion Name (Can be anything)
$AllVmStartChangesTableName =  $env:AllVmStartChangesTableName #Saves all VM restart changes
$PropertyToCompare = "RebootTime"
$PrimaryPropertyKey = "resourceId"
#$UpdatedStorageTableName = "updatedentries"

Write-host $StorageAccountResourceGroup
Write-host $StorageAccountName
Write-host $StorageTableName
Write-host $PropertyToCompare
Write-host $PrimaryPropertyKey
Write-host $AllVmStartChangesTableName

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

    Add-AzTableRow -Table $storageTable.CloudTable -property $hashtable -partitionKey $StorageTablePartitionKey -rowkey $hashtable[$PrimaryPropertyKey].Replace("/", "_")
}


if($UpdatedResult.Count -gt 0)
{
    
    $UpdatedTable = Get-AzStorageTable -Context $storageAccount.Context -Name $AllVmStartChangesTableName
    #Get-AzTableRow -Table $UpdatedTable.CloudTable | Remove-AzTableRow -Table $UpdatedTable.CloudTable
    foreach($element in $UpdatedResult)
    {
        $hashtable = @{}
        foreach( $property in $element.psobject.properties.name )
        {
            $hashtable[$property] = $element.$property
        }

        Add-AzTableRow -Table $UpdatedTable.CloudTable -property $hashtable -partitionKey $StorageTablePartitionKey -rowkey $hashtable[$PrimaryPropertyKey].Replace("/", "_")
    }
    $Body = @{data = (($UpdatedResult | ConvertTo-Html -Fragment) -join "")} | ConvertTo-Json

    #Invoke-RestMethod -Method Post -Uri $env:LOGIC_APP_URL -Body $Body -ContentType "application/json"
}
