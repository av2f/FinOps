$subscriptionId = "09168531-83ff-41b9-b864-3ceccb34f76d"

Set-AzContext -subscriptionId $subscriptionId

$billingPeriod = "{0:yyyyMM}" -f (Get-Date).AddMonths(-1)
Write-Host $billingPeriod


$disks = (Get-AzConsumptionUsageDetail -BillingPeriodName $billingperiod | Where-Object InstanceId -Like "*/disks/*")

$totalCost = 0
foreach ($disk in $disks) {
  if ($disk.InstanceName -eq "srsdc707019w001-IdentityDisk-1krpr") {
    write-Host $disk.product " - " $disk.InstanceName " - " $disk.PretaxCost " - " $disk.InstanceId " - " $disk.MeterId
    $totalCost += $disk.PretaxCost
  }
}

Write-Host "Total Cost Disks = " $totalCost