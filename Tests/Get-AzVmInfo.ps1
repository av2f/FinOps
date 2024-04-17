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
$globalVar = Get-Content -Raw -Path ".\GetAzVmInfo.json" | ConvertFrom-Json
#
# $globalError = 0  # to count errors
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

function GetWinVmInfoFromSubscription
{
  param(
    [String]$subscriptionId
  )
  <#
  $listVms = (Get-AzVm -Status |
    # Where-Object { $_.StorageProfile.OSDisk.OsType -eq $($globalVar.osTypeFilter) } |
    ForEach-Object {
      $_.ResourceGroupName, $_.Name, $_.Id, $_.VmId, $_.Location, $_.PowerState, $_.StorageProfile.OSDisk.OsType, $_.OsName,
      $_.LicenseType, $_.HardwareProfile.VmSize } 
      # $_.tags.$($globalVar.tags.environment), $_.tags.$($globalVar.tags.availability)
  )
  #>

  $listVms = (Get-AzVm -Status) | Select-Object -Property ResourceGroupName, Name, Id, VmId, Location, PowerState, OsName, LicenseType,
  @{l="OsType";e={$_.StorageProfile.OSDisk.OsType}}, @{l="VmSize";e={$_.HardwareProfile.VmSize}}
  return $listVms
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
  if ($listResult.Count -ne 12) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroupName = $listResult[2]
      Vm_Name = $listResult[3]
      Vm_Id = $listResult[4]
      Id = $listResult[5]
      Location = $listResult[6]
      PowerState = $listResult[7]
      Os_Type = $listResult[8]
      Os_Name = $listResult[9]
      License_Type = $listResult[10]
      Size = $listResult[11]
      
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


Set-AzContext -Subscription "6e029caa-ce75-433f-9c26-e1ab25e41080"

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
    $listVms = (GetWinVmInfoFromSubscription -subscription $subscription.Id)
    $VmsCount = $listVms | Measure-Object | ForEach-Object count
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($vmsCount) VMs Groups found") }
    Write-Verbose "-- $($vmsCount) Vms found"
    if ($VmsCount -gt 0) {
      $arrayVms=@()
      foreach ($vm in $listVms) {
        $arrayVms += SetObjResult($subscription.Name, $subscription.id,$vm.ResourceGroupName,
        $vm.Name, $vm.Id, $vm.VmId, $vm.Location, $vm.PowerState, $vm.OsType, $vm.OsName, $vm.LicenseType,
        $vm.VmSize)
      }
      $arrayVms | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
    }
  }
}
