function GetAvgCpuUsage
{
  <#
    Calculate the Average CPU Usage in percentage for
    a resource Id and for a retention in days
    Input:
      - $resourceId: Resource Id to calculate CPU usage
      - $metric: Metric to use to calculate
      - $retentionDays: Number of days to calculate the average. Limit max = 30 days
    Output:
      - $resAvgCpuUsage: Average in percentage of CPU usage during the last $retentionDays
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays
  )
  # Define Start and End dates
  $startTime = (Get-Date).AddDays(-$retentionDays)
  $endTime = (Get-Date)

  Write-Host "CPU from " $startTime " to " $endTime

  <#
  # if $retentionDays > 30 days, set up to 7 days
  if ($retentionDays -gt 30) {
    $retentionDays = 7
  }
  #>

  $resAvgCpuUsage = 0
  # Retrieve Average CPU usage in percentage
  $avgCpus = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 00:30:00 |
    ForEach-Object { $_.Data.Average })
  
    # Calculate Average of CPU usage in percentage
  $cpt = 1
  foreach ($avgCpu in $avgCpus) {
    Write-Host $cpt " - " $avgCpu
    $cpt += 1
    $resAvgCpuUsage += $avgCpu
  }  
  return [Math]::Round($resAvgCpuUsage/$avgCpus.count,2)
}

function GetAvgMemUsage
{
  <#
    Calculate the Average Memory (RAM) Usage in MB for
    a resource Id and for a retention in days
    Input:
      - $resourceId: Resource Id to calculate RAM usage
      - $metric: Metric to use to calculate
      - $retentionDays: Number of days to calculate the average. Limit max = 30 days
      - $vmMemory: RAM in MB of the VM the resource Id

    Output:
      - $resAvgMemUsage: Average in MB of RAM usage during the last $retentionDays
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays,
    [Int]$vmMemory
  )
  # Define Start and End dates
  $startTime = (Get-Date).AddDays(-$retentionDays)
  $endTime = (Get-Date)

  # if $retentionDays > 30 days, set up to 7 days
  if ($retentionDays -gt 30) {
    $retentionDays = 7
  }

  $resAvgMemUsage = 0
  # Retrieve Average of available RAM in Byte
  $avgAvailableMems = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00 |
    ForEach-Object { $_.Data.Average })
  
    # Calculate Average of CPU usage in percentage
  foreach ($avgAvailableMem in $avgAvailableMems) {
    Write-Host "Available = $($avgAvailableMem)"
    $resAvgMemUsage += $vmMemory - ($avgAvailableMem/(1024*1024))
  }  
  return [Math]::Floor($resAvgMemUsage/$avgAvailableMems.count)
}

# Metric = "Percentage CPU"
$rId = "/subscriptions/6e029caa-ce75-433f-9c26-e1ab25e41080/resourceGroups/sdc5-07217-prod-rg/providers/Microsoft.Compute/virtualMachines/srsdc507217l000"
$avgPercentCpu = GetAvgCpuUsage -resourceId $rId -metric "Percentage CPU" -retentionDays 60
Write-Host "Result = $($avgPercentCpu)"

# $avgMemAvailable = GetAvgMemUsage -ResourceId $rId -metric "Available Memory Bytes" -retentionDays 7 -vmMemory 16384
# Write-Host "Result usage Mem = $($avgMemAvailable)"