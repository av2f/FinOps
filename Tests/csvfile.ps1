$pathFileSource = "C:\Users\fparment\Documents\AzFinOps\Data\Alstom\ReservedInstances\isfratioblob.csv"
# $pathFileTarget = "C:\Users\fparment\Documents\AzFinOps\Data\Alstom\subscriptions.csv"

$hashFamilySku = @{}

$listFamilySku = Import-Csv -Path $pathFileSource -Delimiter ","

Write-Host $listFamilySku.Count

foreach($familySku in $listFamilySku) {
  $value = $familySku.InstanceSizeFlexibilityGroup + "," + $familySku.Ratio
  $hashFamilySku.Add($familySku.ArmSkuName,$value)
}

