$subscriptionId = "c5ea61f3-1975-4b59-9e9c-66128b8989f3"
# $resourceGroup = "MC_sdc3-07486-prod-aks-01-rg_pasdc307486x001_westeurope"
# $name = "aks-alm4user-28568817-vmss"

Set-AzContext -SubscriptionId $subscriptionId

function GetVmScaleSets
{
  <#
    Retrieve for ResourceGroup following VmScaleSet informations:
    Sku Name, Sku Capacity, Unique Id, Id, Name and Location 
    Input:
      - $resourceGroupName: ResourceGroup Name
    Output:
      - $errorCount: Nb of errors detected
      - $listVmScaleSets: array of results
  #>

  param(
    [String]$resourceGroupName
  )
  
  $listVmScaleSets = @()
  $errorCount = 0

  # Retrieve VMs from $subscriptionId with informations
  try {
    $listVmScaleSets = (Get-AzVmss -ResourceGroupName $resourceGroupName | Select-Object -Property @{l="Instance";e={$_.Sku.Name}}, @{l="Capacity";e={$_.Sku.Capacity}},
    UniqueId, Id, Name, Location -ErrorAction SilentlyContinue)
  }
  catch {
    Write-Host "An error occured retrieving VmScaleSets from ResourceGroup Name $resourceGroupName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VmScaleSets from ResourceGroup Name $resourceGroupName") }
    $listVmScaleSets = @('Error', 'Error', 'Error', 'Error','Error', 'Error')
    $errorCount += 1
  }
  return $errorCount,$listVmScaleSets
}

$listResourceGroups = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName)

if ($($listResourceGroups | Measure-Object | ForEach-Object count) -gt 0) {

  foreach($resourceGroup in $listResourceGroups) {
    Write-Host "ResourceGroup $($resourceGroup.ResourceGroupName)"
    $errorCount, $vmScaleSets = (GetVmScaleSets -resourceGroupName $resourceGroup.ResourceGroupName)

    if ($($vmScaleSets | Measure-Object | ForEach-Object count) -gt 0) {
      foreach($vmScaleSet in $vmScaleSets) {
        Write-Host $vmScaleSet.UniqueId " - " $vmScaleSet.Name " - " $vmScaleSet.Location " - " $vmScaleSet.Instance " - " $vmScaleSet.Capacity
      }  
    }
  }
  
}