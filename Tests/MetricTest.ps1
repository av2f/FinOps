
$subscriptionId = "80f0f1bc-6d6f-4d58-a6ea-6a1aefb4bb21"
$resourceId = "/subscriptions/80f0f1bc-6d6f-4d58-a6ea-6a1aefb4bb21/resourceGroups/sdc3-01252-qual-rg/providers/Microsoft.Compute/virtualMachines/srsdc301252w401"

$startTime = (Get-Date).AddDays(-7)
$endTime = (Get-Date)

Set-AzContext -Subscription $subscriptionId

Get-AzMetric -ResourceId $resourceId -MetricName "Percentage CPU" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00 | ConvertTo-Json | Out-File "testmetrics.json"
$cpu = Get-AzMetric -ResourceId $resourceId -MetricName "Percentage CPU" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00
Get-AzMetric -ResourceId $resourceId -MetricName "Available Memory Bytes" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00 | ConvertTo-Json | Out-File "testMemMetrics.json"
$mem = Get-AzMetric -ResourceId $resourceId -MetricName "Available Memory Bytes" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00
foreach ($data in $cpu.Data) {
  Write-Host "Value =$($data.TimeStamp) : $($data.Average)"
}

foreach ($data in $mem.Data) {
  Write-Host "Value =$($data.TimeStamp) : $($data.Average)"
}




#Write-Host $cpuMetrics.Data | ForEach-Object { "Timestamp: $($_.TimeSeries[0].Timestamp), Avg: $($_.Average), Min: $($_.Minimum), Max: $($_.Maximum)" }

# $result = Get-AzMetric -ResourceId $resourceId -StartTime $startTime -EndTime $endTime -TimeGrain 01:00:00 | ConvertTo-Json

# Write-Host $result
<#

$subscriptionId = "80f0f1bc-6d6f-4d58-a6ea-6a1aefb4bb21"
$resourceGroupName = "sdc3-01252-qual-rg"
# Set your Azure subscription (if you have multiple subscriptions)
Set-AzContext -Subscription $subscriptionId

# Set the resource group and VM names
$vmNames = (Get-AzVM -ResourceGroupName $resourceGroupName | Select-Object -ExpandProperty Name)

# Set the time range for metrics retrieval
$startTime = (Get-Date).AddDays(-7)  # Adjust the time range as needed
$endTime = (Get-Date)

# Loop through each VM
foreach ($vmName in $vmNames) {
    # Get CPU metrics
    $cpuMetrics = Get-AzMetric -ResourceId "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName" `
                    -MetricName "Percentage CPU" -StartTime $startTime -EndTime $endTime -AggregationType Average

    # Get memory metrics
    $memoryMetrics = Get-AzMetric -ResourceId "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName" `
                        -MetricName "Memory Usage" -StartTime $startTime -EndTime $endTime -AggregationType Average

    # Display metrics for the VM
    Write-Host "VM: $vmName"
    Write-Host "CPU Metrics:"
    $cpuMetrics.Data | ForEach-Object { "Timestamp: $($_.TimeSeries[0].Timestamp), Avg: $($_.Average), Min: $($_.Minimum), Max: $($_.Maximum)" }

    Write-Host "Memory Metrics:"
    $memoryMetrics.Data | ForEach-Object { "Timestamp: $($_.TimeSeries[0].Timestamp), Avg: $($_.Average), Min: $($_.Minimum), Max: $($_.Maximum)" }

    Write-Host ""
}
#>