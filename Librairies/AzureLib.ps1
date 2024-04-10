<# --------------------------
Functions for Azure:
- CheckSaveEvery: Checks if the value of saveEvery in the Json file paramater is at least 10

- CheckIfLogin: Checks if already login to Azure and if not the case, ask to log in

- GetSubscriptions : Retrieves subcriptions from a scope: All or a .csv file with subcription name and Id to process

- GetVmsFromRg: Retrieves for VMs from Resource group $rgName retrieving following VMs informations:
  - Name, Location, OsName, PowerState
  - filter by OsType = Windows

- GetVmInfo: Retrieves for VM:
  - OsType, LicenseType, SKU, Environment and Availibity,
  - filter by OsType = Windows

- GetVmSizing: Retrieves for VM the Number of Cores and RAM in MB

- Get-RoleOwnerSubscription: Retrieves the owner(s) declared in IAM for a subscription
-----------------------------#>

function CheckSaveEvery
{
  <#
    Check if the value of saveEvery in the Json file paramater is at least 10
    If not the case, write error message and exit
    Input:
      - $saveEvery
    Output:
      - Exit if error
  #>
  param(
    [Int]$saveEvery
  )

  if ($saveEvery -lt 10) { 
    Write-Host "Error: SaveEvery in json parameter file must greater or equal than 10"
    Write-Host "Error: Current value is $($saveEvery)"
    Write-Host "Error: Change the value and restart the script"
    if ($globalLog) { 
      (WriteLog -fileName $logfile -message "ERROR : Value of saveEvery must be greater or equal than 10" )
      (WriteLog -fileName $logfile -message "ERROR : Current value is $($saveEvery)" )
      (WriteLog -fileName $logfile -message "ERROR : Change the value and restart the script" )
      (WriteLog -fileName $logfile -message "ERROR : script stopped" )
    }
    exit 1
  }
}
# -----------------------------------------------------
function CheckIfLogIn
{
  <#
    Check if already login to Azure
    If not the case, ask to login
    Input:
      - None
    Output:
      - None
  #>

  # Check if already log in
  $context = Get-AzContext

  if (!$context)
  {
      Write-Host "Prior, you must connect to Azure Portal"
      if ($globalLog) { (WriteLog -fileName $logfile -message "WARNING: Not yet connected to Azure") }
      Connect-AzAccount  
  }
  else
  {
    Write-Host "Already connected to Azure"
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Already connected to Azure") }
  }
}
# -----------------------------------------------------
function GetSubscriptions
{
  <#
    Retrieve subcriptions
    Input :
      - $scope: Object table parameter subscriptionsScope in Json parameter file
    Output :
      - Object Table with Subscription Name and Subscription Id
  #>
  param(
    [Object[]]$scope
  )
  $listSubscriptions = @()
  if ($scope.scope -eq "All") {
    # Retrieve all subscriptions enabled
    $listSubscriptions = (Get-AzSubscription | Where-Object -Property State -eq "Enabled")
  }
  else {
    # $scope.scope is .csv file with 2 columns: Name, Id
    # Check if file exists
    if (Test-Path -Path $scope.scope -PathType Leaf) {
      # Retrieve Subscriptions in .csv file
      $listSubscriptions = Import-Csv -Path $scope.scope -Delimiter $scope.delimiter
    }
    else {
      Write-Host "Error: The file defined for subscriptions in Json parameter file was not found."
      Write-Host "Error: Current value is $($scope.scope)"
      Write-Host "Error: Change the parameter in Json parameter file or load the file with right path and name and restart the script."
      if ($globalLog) { 
        (WriteLog -fileName $logfile -message "ERROR : The file defined for subscriptions in Json parameter file was not found." )
        (WriteLog -fileName $logfile -message "ERROR : Current value is $($scope.scope)" )
        (WriteLog -fileName $logfile -message "ERROR : Change the parameter in Json parameter file or load the file with right path and name and restart the script." )
      }
      exit 1
    }
  }
  return $listSubscriptions
}
# -----------------------------------------------------
function GetVmsFromRg
{
  <#
    Retrieve for VMs from Resource group $rgName retrieving following VMs informations:
    Name, Location, OsName, PowerState
    filter by OsType = Windows
    Input:
      - $rgName: Resource Group Name
    Output:
      - $resVms: array of results
  #>
  param(
    [String]$rgName
  )

  $resVms = @()
  try {
    $resVms = (
          Get-AzVM -ResourceGroupName $resourceGroupName.ResourceGroupName -Status |
          Select-Object -Property Name, Location, OsName, PowerState
        )
  }
  catch {
    Write-Host "An error occured retrieving VMs from Resource group $rgName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VMs from Resource group $rgName") }
    $resVms = @('Error', 'Error', 'Error', 'Error')
    $globalError += 1
  }
  return $resVms
}
# ----------------------------------------------------------
function GetVmInfo
{
  <#
    Retrieve for VM:
    OsType, LicenseType, SKU, Environment and Availibity,
    filter by OsType = Windows
    Input:
      - $rgName: Resource Group Name
      - $vmName: Virtual Machine Name
    Output:
      - $resInfos: array of results
  #>
  param(
    [String]$rgName,
    [String]$vmName
  )
  $resInfos = @()
  try {
    $resInfos = (Get-AzVM -ResourceGroupName $rgName -Name $vmName |
      Where-Object { $_.StorageProfile.OSDisk.OsType -eq $($globalVar.osTypeFilter) } |
      ForEach-Object {
        $_.StorageProfile.OSDisk.OsType, $_.LicenseType, $_.HardwareProfile.VmSize,
        $_.tags.$($globalVar.tags.environment), $_.tags.$($globalVar.tags.availability)
      }
    )
    if ($resInfos.count -ne 0) {
      # If Tags are empty, replaced by "-"
      # $resInfos[3] = (ReplaceEmpty -checkStr $resInfos[3] -replacedBy "-")
      # $resInfos[4] = (ReplaceEmpty -checkStr $resInfos[4] -replacedBy "-")
    }
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VM informations for $vmName") }
    $resInfos = @('Error', 'Error', 'Error', 'Error', 'Error')
    $globalError += 1
  }
  return $resInfos
}
# ----------------------------------------------------------
function GetVmSizing
{
  <#
    Retrieve for VM: Number of Cores and RAM in MB
    Input:
      - $rgName: Resource Group Name
      - $vmName: Virtual Machine Name
      - $sku: SKU of Virtual Machine
    Output:
      - $resSizing: array of results
  #>
  param(
    [String]$rgName,
    [String]$vmName,
    [String]$sku
  )
  $resSizing = @()
  try {
    $resSizing = (Get-AzVMSize -ResourceGroupName $rgName -VMName $vmName |
      Where-Object { $_.Name -eq $($sku) } |
      Select-Object -Property NumberOfCores, MemoryInMB
    )
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VM informations for $vmName") }
    $resSizing = @('Error', 'Error')
    $globalError += 1
  }
  return $resSizing
}
# ----------------------------------------------------------
function Get-RoleOwnerSubscription
{
  <#
    Retrieve the owner(s) declared in IAM for a subscription
    Input :
      - subscription : subscrption name for which the owner(s) must be sought
    Output : 
      - $ownerAssignment : String which contains owner(s) with format : Owner1_name[Type]-Owner2_name[Type]-...
      - $count : Number of Owner found
  #>
  param(
    [Object[]]$subscription
  )
  $ownerAssignment = ""
  $roleAssignments = (Get-AzRoleAssignment -Scope /subscriptions/$($subscription.Id) | Where-Object {$_.RoleDefinitionName -eq "Owner"} | Select-Object -Property DisplayName, ObjectType)
  $count = $roleAssignments.count
  if($count -ne 0)
  {
    foreach($roleAssignment in $roleAssignments)
    {
      $owner = $roleAssignment.DisplayName + '[' + $roleAssignment.ObjectType +']-'
      $ownerAssignment += $owner
    }
  }
  return $ownerAssignment, $count
}
# ----------------------------------------------------------
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

  # if $retentionDays > 30 days, set up to 7 days
  if ($retentionDays -gt 30) {
    $retentionDays = 7
  }
  
  $resAvgCpuUsage = 0
  # Retrieve Average CPU usage in percentage
  $avgCpus = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00 |
    ForEach-Object { $_.Data.Average })
  
    # Calculate Average of CPU usage in percentage
  foreach ($avgCpu in $avgCpus) {
    $resAvgCpuUsage += $avgCpu
  }
  return [Math]::Round($resAvgCpuUsage/$avgCpus.count,2)
}
# ----------------------------------------------------------
function GetAvgMemUsage
{
  <#
    Calculate the Average Memory (RAM) Usage in percentage for
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

  # Process if $vmMemory greater than 0
  If ($vmMemory -gt 0) {
    $resAvgMemUsage = 0
    
    $startTime = (Get-Date).AddDays(-$retentionDays)
    $endTime = (Get-Date)

    # if $retentionDays > 30 days, set up to 7 days
    if ($retentionDays -gt 30) {
      $retentionDays = 7
    }

    # Retrieve Average of available RAM in Bytes
    $avgAvailableMems = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 1.00:00:00 |
      ForEach-Object { $_.Data.Average })
    
      # Calculate Average of Memory usage in percentage
    foreach ($avgAvailableMem in $avgAvailableMems) {
      # if value is null, $avgAvailableMem = $vmMemory in Bytes
      if ($null -eq $avgAvailableMem) {
        $avgAvailableMem = $vmMemory * 1024 * 1024
      }
      $resAvgMemUsage += (($vmMemory - ($avgAvailableMem/(1024*1024))) * 100) / $vmMemory
      $resAvgMemUsage = [Math]::Round($resAvgMemUsage/$avgAvailableMems.count,2)
    }
  }
  # else $resAvgMemUsage = 0
  else { $resAvgMemUsage = 0 }
  
  return $resAvgMemUsage
}