
$targetFile = "C:/Users/fparment/Documents/AzFinOps/Data/ReservedInstances/Instances.csv"
$instances = @()

# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzVmUsageRi.json" | ConvertFrom-Json

$listInstances = Import-Csv -Path $globalVar.reservedInstance.sourceFile -Delimiter "," | Where-Object -Property type -eq  $($globalVar.reservedInstance.type) |
  Select-Object -Property 'Product name'

foreach ($instance in $listInstances) {
  $instances += @(
      [PSCustomObject]@{
        Instance = $instance.'Product name'
      }
    )
}
$instances | Export-Csv -Path $targetFile -Delimiter ";" -NoTypeInformation -Append

Write-Host $listInstances.Count