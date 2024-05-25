<#
  Name    : Get-AzDiskInfo.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 05/24/2024
                   
  Retrieve Disk informations and store result in file GetAzDiskInfo[mmddyyyyhhmmss].csv

  See Readme.md file for more information.
    
  For more information, type Get-Help .\Get-AzDiskInfo.ps1 [-detailed | -full]

  Global variables are stored in .\Get-AzDiskInfo.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzDiskInfo.json" | ConvertFrom-Json
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

function GetDiskInfo {
  <#
    Retrieve Disk informations
    Input :
      - $resourceGroupName: Object table parameter subscriptionsScope in Json parameter file
    Output :
      - $errorCount: Nb of errors detected
      - $listDisks: array of results
  #>
  param (
    [string]$resourceGroupName
  )

  $listDisks = @()
  $errorCount = 0

  # Retrieve Disks from $resourceGroupName with informations
  try {
    $listDisks = (Get-AzDisk -ResourceGroupName $resourceGroupName |
    Select-Object -Property ManagedBy, @{l="SkuName";e={$_.Sku.Name}}, @{l="SkuTier";e={$_.Sku.Tier}},
    TimeCreated, DiskSizeGB, DiskIOPSReadWrite, DiskMBpsReadWrite, DiskState, Name, Location)
  }
  catch {
    Write-Host "An error occured retrieving Disks from ResourceGroup $resourceGroupName"
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: An error occured retrieving Disks from ResourceGroup $resourceGroupName") }
    $listDisks = @('Error', 'Error', 'Error', 'Error','Error', 'Error', 'Error', 'Error','Error', 'Error')
    $errorCount += 1
  }
  return $errorCount, $listDisks
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
  if ($listResult.Count -ne 13) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroup = $listResult[2]
      Disk_Name = $listResult[3]
      Location = $listResult[4]
      State = $listResult[5]
      Date_Created = $listResult[6]
      Sku_Name = $listResult[7]
      Sku_Tier = $listResult[8]
      Size_In_GB = $listResult[9]
      IOPSReadWrite = $listResult[10]
      MBpsReadWrite = $listResult[11]
      Managed_By = $listResult[12]
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
if ($subscriptions.Count -gt 0) {
  foreach ($subscription in $subscriptions) {
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    Set-AzContext -Subscription $subscription.Id | Out-Null
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of the $($subscription.Name) subscription.") }
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    $countDisk = 0
    $arrayDisk = @()
    <# ------------
      ResourceGroup processing
    ------------ #>
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resource Groups from $($subscription.Name)") }
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroups = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName | Sort-Object ResouceGroupName)
    # As there is a bug with .Count when only 1 resource group, replace by "$resourceGroups | Measure-Object | ForEach-Object count"
    $resourceGroupsCount = $resourceGroups | Measure-Object | ForEach-Object Count
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($resourceGroupsCount) Resource Groups found") }
    Write-Verbose "-- $($resourceGroupsCount) Resource Groups found"
    if ($resourceGroupsCount -gt 0) {
      foreach ($resourceGroup in $resourceGroups) {
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resource Group $($resourceGroup.ResouceGroupName))") }
        Write-Verbose "-- Processing of Resource Group $($resourceGroup.ResouceGroupName)"
        $errorCount, $disks = (GetDiskInfo -resourceGroupName $resourceGroup.ResouceGroupName)
        $globalError += $errorCount
        $diskCount = $disks | Measure-Object | ForEach-Object Count
        # if at least a disk
        if ($diskCount -gt 0) {
          foreach ($disk in $disks) {
            if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($diskCount) disks found") }
            Write-Verbose "-- $($diskCount) disks found"
            # Aggregate informations
            $arrayDisk += SetObjResult @(
              $subscription.Name, $subscription.Id, $resourceGroup.ResourceGroupName,
              $disk.Name, $disk.Location, $disk.DiskState, $disk.TimeCreated,
              $disk.SkuName, $disk.SkuTier, $disk.DiskSizeGB, $disk.DiskIOPSReadWrite,
              $disk.DiskMBpsReadWrite, $disk.ManagedBy
            )
            $diskTotal += 1
            $countDisk += 1
            # if number of resources = SaveEvery in json file parameter, write in the result file and re-initiate the array and counter
            if ($countDisk -eq $globalVar.saveEvery) {
              $arrayDisk | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
              $arrayDisk = @()
              $countDisk = 0
            }
          }
        }
      }
      # Write last Disks
      if ($countDisk -gt 0) { $arrayDisk | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append }
      if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $diskTotal disks found and processed") }
      Write-Verbose "--- $diskTotal disks found and processed"
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
