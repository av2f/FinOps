
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