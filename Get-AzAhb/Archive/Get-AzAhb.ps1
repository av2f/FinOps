<#
  Name    : Get-AzAhb.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 04/02/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Help to optimize Azure Hybrid Benefit (AHB) management

  Build a .csv file that contains for each Windows VMs:
  - Subscription Name
  - Subscription Id
  - Resource Group Name
  - VM Name
  - Location
  - PowerState
  - OS Type
  - OS Name (when specified in Azure)
  - License Type: 
    - if "Windows_Server" then AHB is applied
    - if "Windows_Client" then Azure Virtual Desktop is applied
  - Size of VM
  - Number of Cores of VMs
  - RAM of VMs
  - Tag Environment (if exists and specified in the Json file parameter)
  - Tag Availability (if exists and specified in the Json file parameter)
  - Calculate for each VMs:
    - Average CPU usage in percentage during the retention days indicated in the Json parameter file
    - Average Memory usage in percentage during the retention days indicated in the Json parameter file
  - Calculate if AHB applied
    - Number of AHB cores consumed
    - Number of AHB licenses consumed
    - Number of AHB cores wasted (based on Number of cores by licenses specified in the Json file parameter)
    - Number of AHB cores wasted when VM is in powerstate "Deallocated"
  in result file GetAzAhb[mmddyyyyhhmmss].csv
  
  For more information, type Get-Help .\Get-AzAhb.ps1 [-detailed | -full]

  Global variables are stored in .\GetAzAhb.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path ".\GetAzAhb.json" | ConvertFrom-Json
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

function ReplaceEmpty
{
  <#
    Replace an empty string by string given in parameter
    Input:
      - $checkStr: String to check
      - $replacedBy: String to set up if $checkStr is empty
    Output: 
      - $checkStr
  #>
  param(
    [String]$checkStr,
    [String]$replacedBy
  )
  if ($checkStr -match "^\s*$") { $checkStr = $replacedBy }
  return $checkStr
}

function CalcCores
{
  <#
    Retrieve for VM with Hybrid Benefit number of:
    - Cores consumed
    - Licenses consumed
    - Cores wasted
    Input:
      - $nbCores: number of cores of the VM
      - $coresByLicense: Number of cores by license
      - $licenseType: Type of License applied on VM
    Output:
      - $calcCores: array of results
  #>
  param(
    [Int]$nbCores,
    [Int]$coresByLicense,
    [String]$licenseType,
    [String]$powerState
  )

  $calcCores = @{
    coresConsumed = 0
    licensesConsumed = 0
    coresWasted = 0
    coresDeallocatedWasted = 0
  }
  $stateDeallocated = "deallocated"
  $floor = [Math]::Floor($nbCores/$coresByLicense)
  $modulus = $nbCores % $coresByLicense
  # if License applied is Hybrid Benefit
  if ($licenseType -eq $globalVar.hybridBenefit.LicenseType) {
    if ($floor -eq 0 -or $nbCores -eq $coresByLicense) {
      $calcCores['coresConsumed'] = $coresByLicense
      $calcCores['licensesConsumed'] = 1
      $calcCores['coresWasted'] = $coresByLicense - $nbCores
    }
    else {
      switch ($modulus) {
        { $_ -eq 0 } {
          $calcCores['coresConsumed'] = $coresByLicense * $floor
          $calcCores['licensesConsumed'] = $floor
          $calcCores['coresWasted'] = 0
        }
        { $_ -gt 0 } {
          $calcCores['coresConsumed'] = ($coresByLicense * $floor) + $coresByLicense
          $calcCores['licensesConsumed'] = $floor + 1
          $calcCores['coresWasted'] = ($coresByLicense * ($floor + 1)) - $nbCores
        }
      }
    }
    if ($powerState.ToLower().contains($stateDeallocated)) {
      $calcCores['coresDeallocatedWasted'] = $calcCores['coresConsumed']
    }
  }
  return $calcCores
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
        $_.Id, $_.StorageProfile.OSDisk.OsType, $_.LicenseType, $_.HardwareProfile.VmSize,
        $_.tags.$($globalVar.tags.environment), $_.tags.$($globalVar.tags.availability)
      }
    )
    <#
    if ($resInfos.count -ne 0) {
      If Tags are empty, replaced by "-"
      $resInfos[4] = (ReplaceEmpty -checkStr $resInfos[3] -replacedBy "-")
      $resInfos[5] = (ReplaceEmpty -checkStr $resInfos[4] -replacedBy "-")
    } #>
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving VM informations for $vmName") }
    $resInfos = @('Error','Error', 'Error', 'Error', 'Error', 'Error')
    $globalError += 1
  }
  return $resInfos
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

function GetAvgCpuUsage
{
  <#
    Calculate the Average CPU Usage in percentage for
    a resource Id and for a retention in days
    Input:
      - $resourceId: Resource Id to calculate CPU usage
      - $metric: Metric to use to calculate
      - $retentionDays: Number of days to calculate the average. Limit max = 30 days
      - $timeGrain: Granularity of time
    Output:
      - $resAvgCpuUsage: Average in percentage of CPU usage during the last $retentionDays
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays,
    [TimeSpan]$timeGrain
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
  $avgCpus = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain $timeGrain |
    ForEach-Object { $_.Data.Average })
  
    # Calculate Average of CPU usage in percentage
  foreach ($avgCpu in $avgCpus) {
    $resAvgCpuUsage += $avgCpu
  }
  return [Math]::Round($resAvgCpuUsage/$avgCpus.count,2)
}

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
      - $timeGrain: Granularity of time

    Output:
      - $resAvgMemUsage: Average in MB of RAM usage during the last $retentionDays
  #>
  param(
    [String]$resourceId,
    [String]$metric,
    [Int16]$retentionDays,
    [Int]$vmMemory,
    [TimeSpan]$timeGrain
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
    $avgAvailableMems = (Get-AzMetric -ResourceId $resourceId -MetricName $metric -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain $timeGrain |
      ForEach-Object { $_.Data.Average })
    
      # Calculate Average of Memory usage in percentage
    foreach ($avgAvailableMem in $avgAvailableMems) {
      # if value is null, $avgAvailableMem = $vmMemory in Bytes
      if ($null -eq $avgAvailableMem) {
        $avgAvailableMem = $vmMemory * 1024 * 1024
      }
      $resAvgMemUsage += (($vmMemory - ($avgAvailableMem/(1024*1024))) * 100) / $vmMemory
    }
    # Calculate Average
    $resAvgMemUsage = [Math]::Round($resAvgMemUsage/$avgAvailableMems.count,2)
  }
  # else $resAvgMemUsage = 0
  else { $resAvgMemUsage = 0 }
  
  return $resAvgMemUsage
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
  if ($listResult.Count -ne 20) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-','-','-','-','-','-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroup = $listResult[2]
      Vm_Name = $listResult[3]
      Location = $listResult[4]
      PowerState = $listResult[5]
      Os_Type = $listResult[6]
      Os_Name = $listResult[7]
      License_Type = $listResult[8]
      Size = $listResult[9]
      Nb_Cores = $listResult[10]
      Ram = $listResult[11]
      Tag_Environment = $listResult[12]
      Tag_Availability = $listResult[13]
      Avg_CPU_Usage_Percent = $listResult[14]
      Avg_Mem_Usage_Percent = $listResult[15]
      Nb_AHB_Cores_Consumed = $listResult[16]
      Nb_AHB_Licenses_Consumed = $listResult[17]
      Nb_AHB_Cores_Wasted = $listResult[18]
      NB_AHB_Cores_Deallocated_Wasted = $listResult[19]
    }
  )
  return $objTagResult
}
#
<# ------------------------------------------------------------------------
Main Program
--------------------------------------------------------------------------- #>
# Create directory results if not exists and filename for results
if ((CreateDirectoryResult $globalVar.pathResult)) {
  # Create the CSV file result
  $csvResFile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'csv' -chrono $globalVar.chronoFile)
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
    Set-AzContext -Subscription $subscription.Id
    <# ------------
      ResourceGroup processing
    ------------ #>
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resource Groups from $($subscription.Name)") }
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    # Retrieve Resource groups names from the subscription
    $resourceGroupNames = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName | Sort-Object ResouceGroupName)
    # As there is a bug with .Count when only 1 resource group, replace by "$resourceGroupNames | Measure-Object | ForEach-Object count"
    $resourceGroupNamesCount = $resourceGroupNames | Measure-Object | ForEach-Object Count
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($resourceGroupNamesCount) Resource Groups found") }
    Write-Verbose "-- $($resourceGroupNamesCount) Resource Groups found"
    if ($resourceGroupNamesCount -ne 0) {
      foreach ($resourceGroupName in $resourceGroupNames) {
        $arrayVm = @()
        $countVm = 0
        <# ------------
          VMs processing
          Retrieve VMs from Resource group $resourceGroupName
        ------------ #>
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of VMs from Resource Group $($resourceGroupName.ResourceGroupName)") }
        Write-Verbose "--- Processing of VMs from Resource Group $($resourceGroupName.ResourceGroupName)"
        $vms = GetVmsFromRg -rgName $resourceGroupName
        # Continue if there are Virtual Machines
        # As there is a bug with .Count when only 1 VM, replace by "$vms | Measure-Object | ForEach-Object count"
        if ($($vms | Measure-Object | ForEach-Object count) -ne 0) {
          $windowsVm = 0  # Count number of Windows VM in the RG
          foreach ($vm in $vms) {
            # -- Retrieve VM informations
            $vmInfos = GetVmInfo -rgName $resourceGroupName.ResourceGroupName -vmName $vm.Name
            # if VM matching with $globalVar.osTypeFilter
            if ($vmInfos.Count -ne 0) {
              # -- Retrieve VM sizing
              $vmSizing = GetVmSizing -rgName $resourceGroupName.ResourceGroupName -vmName $vm.Name -sku $vmInfos[3]
              # -- Calculate Cores and Licenses for Hybrid Benefits
              $resultCores = CalcCores -nbCores $vmSizing.NumberOfCores -coresByLicense $globalVar.weightLicenseInCores -licenseType $vmInfos[2] -powerState $vm.PowerState
              # -- Calculate CPU usage in percentage
              $avgPercentCpu = (
                GetAvgCpuUsage -resourceId $vmInfos[0] -metric $globalVar.metrics.cpuUsage -retentionDays $globalVar.metrics.retentionDays -timeGrain 1.00:00:00
              )
              # -- Calculate Memory usage in percentage
              $avgPercentMem = (
                GetAvgMemUsage -ResourceId $vmInfos[0] -metric $globalVar.metrics.memoryAvailable -retentionDays $globalVar.metrics.retentionDays -vmMemory $vmSizing.MemoryInMB -timeGrain 1.00:00:00
              )
              # Aggregate informations
              $arrayVm += SetObjResult @(
                $subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName,
                $vm.Name, $vm.Location, $vm.PowerState,
                $vmInfos[1], $vm.OsName, $vmInfos[2],
                $vmInfos[3], $vmSizing.NumberOfCores, $vmSizing.MemoryInMB,
                $vmInfos[4],$vmInfos[5],$avgPercentCpu, $avgPercentMem, $resultCores['CoresConsumed'],
                $resultCores['licensesConsumed'], $resultCores['coresWasted'], $resultCores['coresDeallocatedWasted']
              )
              $windowsVm += 1
              $countVm += 1
              # if number of resources = SaveEvery in json file parameter, write in the result file and re-initiate the array and counter
              if ($countVm -eq $globalVar.saveEvery) {
                $arrayVm | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
                $arrayVm = @()
                $countVm = 0
              }
            }
          }
          # Write last Vms
          if ($countVm -gt 0) { $arrayVm | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append }
          if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $windowsVm VMs Windows found and processed") }
          Write-Verbose "--- $windowsVm VMs Windows found and processed"
        }
      }
    }
    Write-Verbose "---------------------------------------------"
  }
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: File $csvResFile is available.") }
  Write-Verbose "File $csvResFile is available."
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
