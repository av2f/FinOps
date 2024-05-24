# $disks = Get-Content -Raw -Path ".\disk.json" | ConvertFrom-Json

Set-AzContext -SubscriptionId "6e029caa-ce75-433f-9c26-e1ab25e41080"

$resourceGroups = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName | Sort-Object ResouceGroupName)

$resourceGroupsCount = $resourceGroups | Measure-Object | ForEach-Object Count

if ($resourceGroupsCount -gt 0) {
  foreach ($resourceGroup in $resourceGroups) {
    $disks = (Get-AzDisk -ResourceGroupName $resourceGroup.ResouceGroupName)
    $disksCount = $disks | Measure-Object | ForEach-Object Count
    if ($disksCount -gt 0) {
      foreach ($disk in $disks) {
        Write-Host $disk.Name " - " $disk.DiskSizeGB " - " $disk.Sku.Name " - " $disk.Sku.Tier " - " $disk.DiskState " - " $disk.TimeCreated
      }
    }
  }
}