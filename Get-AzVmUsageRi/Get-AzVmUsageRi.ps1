<#
  Name    : Get-AzVmUsageRi.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 06/06/2024
                   
  Retrieve CPU usage for all VMs in subscriptions scope defined

  Build a .csv file that contains for each Windows VMs:
  - Subscription Name
  - Resource Group Name
  - VM Name
  - Location
  - PowerState
  - OS Type
  - OS Name (when specified in Azure)
  - Size of VM
  - Number of Cores of VMs
  - RAM of VMs
  - Calculate for each VMs during the retention days and the time grain indicated un the Json parameter file:
    - CPU 
      + Average CPU usage in percentage
      + Max CPU usage in percentage
      + Min CPU usage in percentage

      in result file GetAzVmUsageRi[mmddyyyyhhmmss].csv

  + Create the file Instances[mmddyyyyhhmmss].csv with 1 column containing VM Size
  
  For more information, type Get-Help .\Get-AzVmUsageRi.ps1 [-detailed | -full]

  Global variables are stored in .\Get-AzVmUsageRi.json and must be adapted accordingly
#>

<# -----------
  Declare input parameters
----------- #>
[cmdletBinding()]

param()

# --- Disable breaking change Warning messages in Azure Powershell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

<# -----------
  Declare global variables, arrays and objects
----------- #>
# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzVmUsageRi.json" | ConvertFrom-Json
#
$globalError = 0  # to count errors
$globalChronoFile = (Get-Date -Format "MMddyyyyHHmmss") # Format for file with chrono
$globalLog = $false # set to $true if generateLogFile in json file is set to "Y"

<# -----------
  Declare Functions
----------- #>
function CreateDirectoryResult{
  <#
    Create Directory to store result files if not already existing
    Input:
      - $directory: directory name to create if not already existing
    Output: 
      - $True
  #>
  param(
    [String]$directory
  )
  if ((Test-Path -Path $directory) -eq $False) {
    New-Item -Path $directory -ItemType "directory"
  }
  return $True
}

function CreateFile
{
  <#
    Create file with chrono with format : <filename>MMddyyyyHHmmss
    Input:
      - $pathName: Path where create file
      - $fileName: File name
      - $extension: Extension of file to create
      - $chrono: Y|N - Specify if the file must be created with format $fileNameMMddyyyyHHmmss
    Output: 
      - $resFileName = File name accordingly options
    Use the variable $globalChronoFile in Json file parameter to set up the chrono
  #>
  param(
    [String]$pathName,
    [String]$fileName,
    [String]$extension,
    [String]$chrono
  )
  $resFileName = ""
  # if Chrono set to "Y"
  if ($chrono.ToUpper() -eq "Y") {
    $resFileName =$pathName + $fileName + $globalChronoFile + '.' + $extension
  }
  else {
    # Remove file if already exists to create a new
    $resFileName = $pathName + $fileName + "." + $extension 
    if (Test-Path -Path $resFileName -PathType Leaf)
    {
      Remove-Item -Path $resFileName -Force
    }
  }
  return $resFileName
}

function WriteLog
{
  <#
    write in the log file with format : MM/dd/yyyy hh:mm:ss: message
    Input:
      - $fileName: Log file name
      - $message: message to write
    Output: 
      - write in the log file $fileName
  #>
  param(
    [string]$fileName,
    [string]$message
  )
  $chrono = (Get-Date -Format "MM/dd/yyyy hh:mm:ss")
  $line = $chrono + ": " + $message
  Add-Content -Path $fileName -Value $line
}

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

function GetTimeGrain
{
  <#
    Create the TimeSpan from the timegrain defined in string
    the format must be [days.]Hours:Minutes.Seconds (days is optional)
    if the format provided in paramater is not good, by default result is 1.00:00:00 (1 day)
    Input :
      - $timeGrain: String with format [days.]Hours:Minutes.Seconds
    Output :
      - $timeSpan: TimeSpan created
  #>

  param(
    [String]$timeGrain
  )

  if ( $timeGrain -match "([0-9])?(.)?([0-2][0-9]):([0-5][0-9]):([0-5][0-9])") {
    # Format of $timeGrain is OK
    # Build TimeGrain
    if ($null -eq $matches[1]) { $days = 0 }
    else { $days = $matches[1] }
    $timeSpan = New-TimeSpan -Days $days -Hours $matches[3] -Minutes $matches[4] -Seconds $matches[5]
    Write-Verbose "TimeGrain defined is $timeSpan"
    if ($globalLog) { WriteLog -fileName $logfile -message "TimeGrain defined is $timeSpan" }
  }
  else {
    # Set a timeSpan by Default at 1 day
    $timeSpan = New-TimeSpan -Days 1 -Hours 0 -Minutes 0 -Seconds 0
    Write-Verbose "ERROR: the TimeGrain provides in parameter ($timeGrain) has a bad format."
    Write-Verbose "ERROR: TimeSpan defined by default is 1 day."
    if ($globalLog) { WriteLog -fileName $logfile -message "ERROR: the TimeGrain provides in parameter ($timeGrain) has a bad format." }
    if ($globalLog) { WriteLog -fileName $logfile -message "ERROR: TimeSpan defined by default is 1 day." }
  }
  return $timeSpan
} 

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
      $srcListSubscriptions = Import-Csv -Path $scope.scope -Delimiter $scope.delimiter
      
      # Perform a sanity check of the list
      Write-Host "Please wait, Cheking the subscription list..."
      Write-Verbose "Cleaning the subscription list..."
      if ($globalLog) { WriteLog -fileName $logfile -message "Cleaning the subscription list..." }
      $listSubscriptions = @()
      $nbErrorSubscription = 0
      
      foreach ($subscription in $srcListSubscriptions) {
        $GetSubscription = (Get-AzSubscription -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue)
        # Subscription no longer exists or is disabled
        if (!$GetSubscription -or $GetSubscription.State -ne "Enabled") {
          Write-Verbose "the $($subscription.Name) no longer exists or is disabled"
          if ($globalLog) { WriteLog -fileName $logfile -message "the $($subscription.Name) no longer exists or is disabled" }
          $nbErrorSubscription +=1
        }
        # Else add to array
        else { $listSubscriptions += $subscription }
      }
      if ($nbErrorSubscription -eq 0) {
        Write-Verbose "All subscriptions on $($listSubscriptions.count) are valid."
        if ($globalLog) { WriteLog -fileName $logfile -message "All subscriptions on $($listSubscriptions.count) are valid." }
      }
      else {
        Write-Verbose "$nbErrorSubscription subscriptions on $($srcListSubscriptions.count) are no longer valid."
        if ($globalLog) { WriteLog -fileName $logfile -message "$nbErrorSubscription subscriptions on $($srcListSubscriptions.count) are no longer valid." }
      }
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

function GetVmInfoFromSubscription
{
  <#
    Retrieve for VMs from the current subscription, retrieving following VMs informations:
    ResourceGroupName, VM Name, VM Id, VmId, Location, PowerState, OsType, OsName, LicenseType, VM Size
    Input:
      - $subscriptionId: Subscription ID
    Output:
      - $errorCount: Nb of errors detected
      - $listVms: array of results
  #>

  param(
    [String]$subscriptionId
  )
  
  $listVms = @()
  $errorCount = 0

  # Retrieve VMs from $subscriptionId with informations
  try {
    $listVms = (Get-AzVm -Status | Select-Object -Property ResourceGroupName, Name, Id, VmId, Location, PowerState, OsName, LicenseType,
    @{l="OsType";e={$_.StorageProfile.OSDisk.OsType}}, @{l="VmSize";e={$_.HardwareProfile.VmSize}} -ErrorAction SilentlyContinue)
  }
  catch {
    Write-Host "An error occured retrieving VMs from Subscription Id $subscriptionId"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VMs from Subscription Id $subscriptionId") }
    $listVms = @('Error', 'Error', 'Error', 'Error','Error', 'Error', 'Error', 'Error','Error', 'Error')
    $errorCount += 1
  }
  return $errorCount,$listVms
}

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
  $errorCount = 0

  try {
    $resSizing = (Get-AzVMSize -ResourceGroupName $rgName -VMName $vmName |
      Where-Object { $_.Name -eq $($sku) } |
      Select-Object -Property NumberOfCores, MemoryInMB -ErrorAction SilentlyContinue
    )
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VM informations for $vmName") }
    $resSizing = @('Error', 'Error')
    $errorCount += 1
  }
  return $errorCount,$resSizing
}

function GetPercentCpuUsage
{
  <#
    Calculate in percentage for a resource Id and for a retention in days
      - the Average CPU usage
      - the Max CPU usage reached
      - the Min CPU usage reached
      - the number of time the limit is reached
    Input:
      - $resourceId: Resource Id to calculate CPU usage
      - $metric: Metric to use to calculate
      - $retentionDays: Number of days to calculate the average. Limit max = 30 days
      - $timeGrain: Granularity of time
      - $limitCpu: in percentage, to calculate the number of time this limit is reached
    Output:
      - $calcCpuUsage: Array with data calculated
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays,
    [TimeSpan]$timeGrain,
    [Int16]$limitCpu
  )
  
  # Initiate Result Array
  $calcCpuUsage = @{
    average = 0
    maxReached = 0
    minReached = 100
    countLimitReached = 0
  }
  
  # Define Start and End dates
  $startTime = (Get-Date).AddDays(-$retentionDays)
  $endTime = (Get-Date)
    
  # if $retentionDays > 30 days, set up to 30 days
  <#
  if ($retentionDays -gt 30) {
    $retentionDays = 30
  }
  #>

  # Retrieve Average CPU usage in percentage
  $avgCpus = (
    Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain $timeGrain |
      ForEach-Object { $_.Data.Average } -ErrorAction SilentlyContinue
  )
  # If Metrics are available
  if ($avgCpus.count -gt 0) {
    # Calculate Average of CPU usage in percentage
    foreach ($avgCpu in $avgCpus) {
      $calcCpuUsage['average'] += $avgCpu
      # Max processing
      if ([Math]::Round($avgCpu,2) -gt $calcCpuUsage['maxReached']) { $calcCpuUsage['maxReached'] = [Math]::Round($avgCpu,2) }
      # Min Processing
      if ([Math]::Round($avgCpu,2) -lt $calcCpuUsage['minReached']) { $calcCpuUsage['minReached'] = [Math]::Round($avgCpu,2) }
      # Limit Processing
      if ($avgCpu -gt $limitCpu) { $calcCpuUsage['countLimitReached'] += 1 }
    }
    # Average processing
    $calcCpuUsage['average'] = [Math]::Round($calcCpuUsage['average']/$avgCpus.count,2)
  }
  # else all result from array = 0
  else { $calcCpuUsage['minReached'] = 0 }
  
  return $calcCpuUsage
}

function GetPercentMemUsage
{
  <#
    Calculate in percentage for a resource Id and for a retention in days
      - the Average Memory usage
      - the Max Memory usage reached
      - the Min Memory usage reached
      - the number of time the limit is reached
    Input:
      - $resourceId: Resource Id to calculate RAM usage
      - $metric: Metric to use to calculate
      - $retentionDays: Number of days to calculate the average. Limit max = 30 days
      - $vmMemory: RAM in MB of the VM the resource Id
      - $timeGrain: Granularity of time
    Output:
      - $calcMemUsage: Array with data calculated
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays,
    [Int]$vmMemory,
    [TimeSpan]$timeGrain,
    [Int16]$limitMem
  )
  
  # Initiate Result Array
  $calcMemUsage = @{
    average = 0
    maxReached = 0
    minReached = 100
    countLimitReached = 0
  }
  
  # Process if $vmMemory greater than 0
  If ($vmMemory -gt 0) {
    
    # Define Start and End dates
    $startTime = (Get-Date).AddDays(-$retentionDays)
    $endTime = (Get-Date)

    # if $retentionDays > 30 days, set up to 30 days
    <#
    if ($retentionDays -gt 30) {
      $retentionDays = 30
    }
    #>

    # Retrieve Average of available RAM in Bytes
    $avgAvailableMems = (
      Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain $timeGrain |
        ForEach-Object { $_.Data.Average } -ErrorAction SilentlyContinue
    )
    # If Metrics are available
    if ($avgAvailableMems.count -gt 0) {
      # Calculate Average of Memory usage in percentage
      foreach ($avgAvailableMem in $avgAvailableMems) {
        # if value is null, $avgAvailableMem = $vmMemory in Bytes
        if ($null -eq $avgAvailableMem) {
          $avgAvailableMem = $vmMemory * 1024 * 1024
        }
        # Convert in MB and in percentage
        $avgAvailableMem = (($vmMemory - ($avgAvailableMem/(1024*1024))) * 100) / $vmMemory
        # $avgMemUsage += (($vmMemory - ($avgAvailableMem/(1024*1024))) * 100) / $vmMemory
        $calcMemUsage['average'] += [Math]::Round($avgAvailableMem,2)
        # Max processing
        if ([Math]::Round($avgAvailableMem,2) -gt $calcMemUsage['maxReached']) { $calcMemUsage['maxReached'] = [Math]::Round($avgAvailableMem,2) }
        # Min Processing
        if ([Math]::Round($avgAvailableMem,2) -lt $calcMemUsage['minReached']) { $calcMemUsage['minReached'] = [Math]::Round($avgAvailableMem,2) }
        # Limit Processing
        if ($avgAvailableMem -gt $limitMem) { $calcMemUsage['countLimitReached'] += 1 }
      }
      # Average processing
      $calcMemUsage['average'] = [Math]::Round($calcMemUsage['average']/$avgAvailableMems.count,2)
    }
    # else all result from array = 0
    else { $calcMemUsage['minReached'] = 0 }
  }
  # else all result from array = 0
  else { $calcMemUsage['minReached'] = 0 }
  
  return $calcMemUsage
}

function SetObjResult {
  <#
    Create Object array with informations contained in the array $listResult
    Input: $listResult
    Output: Object array with informations
  #>
  param(
    [array]$listResult
  )
  if ($listResult.Count -ne 18) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-','-','-','-','-')
  }
  $objResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      ResourceGroup = $listResult[1]
      Vm_Name = $listResult[2]
      Id = $listResult[3]
      Resource_Id = $listResult[4]
      Location = $listResult[5]
      PowerState = $listResult[6]
      Os_Type = $listResult[7]
      Os_Name = $listResult[8]
      Size = $listResult[9]
      Nb_Cores = $listResult[10]
      Ram = $listResult[11]
      Start_Date = $listResult[12]
      End_Date = $listResult[13]
      Avg_CPU_Usage_Percent = $listResult[14]
      Max_CPU_Usage_Percent = $listResult[15]
      Min_CPU_Usage_Percent = $listResult[16]
      Limit_Count_CPU = $listResult[17]
    }
  )
  return $objResult
}

function SetObjInstance {
  <#
    Create Object array with informations contained in the array $listInstance
    Input: $listInstance
    Output: Object array with informations
  #>
  param(
    [array]$listInstance
  )
  if ($listInstance.Count -ne 1) {
    $listInstance = @('-')
  }
  $objInstance = @(
    [PSCustomObject]@{
      Instance = $listInstance[0]
    }
  )
  return $objInstance
}
#
<# ------------------------------------------------------------------------
Main Program
--------------------------------------------------------------------------- #>
# Create directory results if not exists and filenames for results
if ((CreateDirectoryResult $globalVar.pathResult)) {
  # Create the CSV file result
  $csvResFile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'csv' -chrono $globalVar.chronoFile)
  $csvInstanceFile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileInstance -extension 'csv' -chrono $globalVar.chronoFile)
  # if generateLogFile in Json file is set to "Y", create log file
  if ($globalVar.generateLogFile.ToUpper() -eq "Y") {
    # Create log file
    $globalLog = $true
    $logfile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'log' -chrono $globalVar.chronoFile)
  }
}
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Starting processing...") }
Write-Verbose "Starting processing..."
# if variable checkIfLogIn in json file is set to "Y", Check if log in to Azure
if ($globalVar.checkIfLogIn.ToUpper() -eq "Y") { CheckIfLogIn }

# Define the TimeGrain
$timeGrain = (GetTimeGrain -timeGrain $globalVar.metrics.timeGrain)

# retrieve Subscriptions
$subscriptions = (GetSubscriptions -scope $globalVar.subscriptionsScope)
# --
Write-Verbose "$($subscriptions.Count) subscriptions found."
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($subscriptions.Count) subscriptions found.") }
if ($subscriptions.Count -ne 0) {
  foreach ($subscription in $subscriptions) {
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of the $($subscription.Name) subscription.") }
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    Set-AzContext -Subscription $subscription.Id | Out-Null
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Vms from Subscription $($subscription.Name)") }
    Write-Verbose "-- Processing of Vms from Subscription $($subscription.Name)"
    $countVm = 0
    $arrayVm = @()
    $countInstance = 0
    $arrayInstance = @()
    $errorCount, $vms = (GetVmInfoFromSubscription -subscriptionId $subscription.Id)
    $globalError += $errorCount
    # Continue if there are Virtual Machines
    # as there is a bug with .Count when only 1 VM, replace by "$vms | Measure-Object | ForEach-Object count"
    if ($($vms | Measure-Object | ForEach-Object count) -gt 0) {
      $vmTotal = 0
      foreach ($vm in $vms) {
        # -- Retrieve VM sizing
        $errorCount, $vmSizing = (GetVmSizing -rgName $vm.ResourceGroupName -vmName $vm.Name -sku $vm.VmSize)
        $globalError += $errorCount
        # -- Calculate CPU usage in percentage
        $avgPercentCpu = (
          GetPercentCpuUsage -resourceId $vm.Id -metric $globalVar.metrics.cpuUsage -retentionDays $globalVar.metrics.retentionDays -timeGrain $timeGrain -limitCpu $globalVar.limitCountCpu
        )
        <#
        # -- Calculate Memory usage in percentage
        $avgPercentMem = (
          GetPercentMemUsage -ResourceId $vm.Id -metric $globalVar.metrics.memoryAvailable -retentionDays $globalVar.metrics.retentionDays -vmMemory $vmSizing.MemoryInMB -timeGrain $timeGrain -limitMem $globalVar.limitCountMem
        )
        #>
        # Aggregate informations
        $startDate = "{0:MM/dd/yyyy}" -f (Get-Date).AddDays(-$globalVar.metrics.retentionDays)
        $endDate = (Get-Date -Format "MM/dd/yyyy")

        $arrayVm += SetObjResult @(
          $subscription.Name, $vm.ResourceGroupName,
          $vm.Name, $vm.Id, $vm.VmId, $vm.Location, $vm.PowerState,
          $vm.OsType, $vm.OsName, $vm.VmSize,
          $vmSizing.NumberOfCores, $vmSizing.MemoryInMB, $startDate, $endDate
          $avgPercentCpu['average'], $avgPercentCpu['maxReached'], $avgPercentCpu['minReached'], $avgPercentCpu['countLimitReached']
        )
        $countVm += 1
        $vmTotal += 1
        # if VM is in running state, store the VM size in the csv instance file
        if ($vm.PowerState -eq "VM running") {
          $arrayInstance += SetObjInstance @($vm.VmSize)
          $countInstance += 1
        }
        # if number of resources = SaveEvery in json file parameter, write in the result file and re-initiate the array and counter
        if ($countVm -eq $globalVar.saveEvery) {
          $arrayVm | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
          $arrayVm = @()
          $countVm = 0
        }
        if ($countInstance -eq $globalVar.saveEvery) {
          $arrayInstance | Export-Csv -Path $csvInstanceFile -Delimiter ";" -NoTypeInformation -Append
          $arrayInstance = @()
          $countInstance = 0
        }
      }
      # Write last Vms
      if ($countVm -gt 0) { $arrayVm | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append }
      if ($countInstance -gt 0) { $arrayInstance | Export-Csv -Path $csvInstanceFile -Delimiter ";" -NoTypeInformation -Append }
      
      if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $vmTotal VMs found and processed") }
      Write-Verbose "--- $vmTotal VMs found and processed"
    }
    Write-Verbose "---------------------------------------------"
  }
  # Execute script to add instances from reservedinstances.csv in Instances[mmddyyyyhhmmss].csv
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Add instances from reservedinstances.csv file in csv instances file") }
  Write-Verbose "Add instances from reservedinstances.csv file in csv instances file"
  if (Test-Path -Path $globalVar.reservedInstance.sourceFile -PathType Leaf) {
    # if source file exists, run the script
    & $PSScriptRoot\Get-AzInstanceRi.ps1
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Instances added in csv instances file") }
    Write-Verbose "Instances added in csv instances file"
  }
  else {
    if ($globalLog) {
      (WriteLog -fileName $logfile -message "ERROR: the file $($globalVar.reservedInstance.sourceFile) does not exist")
      (WriteLog -fileName $logfile -message "ERROR: Cannot retrieve instances from Reserved instances")
    }
    Write-Verbose "ERROR: the file $($globalVar.reservedInstance.sourceFile) does not exist"
    Write-Verbose "ERROR: Cannot retrieve instances from Reserved instances"
    $globalError =+ 1
  }
  
  if ($globalLog) {
    (WriteLog -fileName $logfile -message "INFO: File $csvResFile is available.")
    (WriteLog -fileName $logfile -message "INFO: File $csvInstanceFile is available.")
  }
  Write-Verbose "File $csvResFile is available."
  Write-Verbose "File $csvInstanceFile is available."
}
else {
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: No Subscriptions enabled found.") }
  Write-Verbose "No Subscriptions enabled found."
}
if ($globalLog) {
  (WriteLog -fileName $logfile -message "INFO: End processing with $globalError error(s)...") 
}

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves informations and perform calculation to optimize Azure Hybrid Benefit (AHB)

  .DESCRIPTION
  The Get-AzAhb script creates the GetAzAhb[mmddyyyyhhmmss].csv file retrieving informations below for each Windows VMs:
  - Subscription Name
  - Subscription ID
  - Resource Groups Name
  - VM Name
  - Location
  - PowerState
  - Os Type
  - Os Name
  - License Type (Windows_Server when AHB applied)
  - VM Size
  - Number of cores and RAM in MB
  - Tag Environment if existing
  - Tag Availability if existing

  In addition, there are:
    - 2 calcultated columns for each VMs
      +Average CPU usage in percentage during the retention days indicated in the Json parameter file
      + Average Memory usage in percentage during the retention days indicated in the Json parameter file
    - 4 calculated columns for VMs for which AHB is applied:
      + Number of AHB cores consumed
      + Number of AHB licenses consumed
      + Number of AHB cores wasted
      + Number of AHB cores wasted when VM is in powerstate "Deallocated"
        
  Prerequisites:
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  Parameters: GetAzAhb.json file
  the GetAzAhb.json file allows to adapt script to context.
  Parameters are:
  - pathResult:
    - Directory where to store results.
    - Format : "C:/Path/subPath/.../"
  
  - fileResult: name of result file and log file (by default, GetAzAhb)
  
  - chronoFile: Y|N.
    - Set to "Y" if you want a chrono in the name of the file.
    - Format: mmddyyyyhhmmss
  
  - generateLogFile: Y|N. Set to "Y" if you want a log file
  
  - checkIfLogIn: Y|N. Set to "Y" if you want to check if log in to Azure is done
  
  - subscriptions: 
    - scope: All|.csv file
      - if you set "All", process all subscription
      - if you set a .csv file, process subscriptions in file
        + format must be: 
          - 1st column : Subscription Name with column named "Name"
          - 2nd column : Subscription Id with column name "Id"
        + example: "scope": "C:/data/subscriptions.csv"
        + example: "scope": "C:/data/subscriptions.csv"
    - delimiter: indicate the delimiter in the .csv file
  
  - osTypeFilter: Os Type to filter. by default "Windows"
  
  - hybridBenefit: Indicates LicenseType to match with AHB
    "licenseType": "Windows_Server",
    "name": "Hybrid Benefit"
  
  - virtualDesktop: Indicates LicenseType to match with Azure Virtual Desktop
    "licenseType": "Windows_Client",
    "name": "Azure Virtual Desktop"
  
  - weightLicenseInCores: Indicates the number of cores for 1 AHB License (by default 8)
  
  - metrics: for the calculation of CPU and Memory usage
    "cpuUsage": Metric name for CPU usage
    "memoryAvailable": Metric name to retrieve the memory available in bytes
    "retentionDays": number of days to calculate CPU Usage & Memory Available. Must be Less or equal than 30

  - tags: 
    "environment": Tag Environment defined in Azure
    "availability": Tag Availability defined in Azure

  .INPUTS
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetAzAhb[MMddyyyyHHmmss].csv file with results.
  Optional: GetAzAhb[MMddyyyyHHmmss].log file with detailed log.

  .EXAMPLE
  .\Get-AzAhb.ps1
  .\Get-AzAhb.ps1 -Verbose : Execute script writing on console progress informations.
  

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>
