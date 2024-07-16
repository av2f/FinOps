<#
  Name    : Get-AzVmCostVariation.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 07/16/2024
  
  Compare costs of Virtual Machines between M-1 and M and calculate USD Cost Variation and variation in percentage.
  
  Global variables are stored in .\Get-AzVmCostVariation.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzVmCostVariation.json" | ConvertFrom-Json
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

function SearchResource()
{
  <#
    Search if VM $resource in the Resource Group $resourceGroupName exists in $listVms
    Input:
      - $resourceGroupName : $ResourceGroupName
      - $resource : $Resource
      - $listVms : List of VMs
    Output: 
      - $cost : Cost in Decimal format of the VM
      - $costUsd : Cost USD in Decimal format of the format
      - $Found : Boolean. $true if VM has been found, else return $false.
  #>
  param(
    [string]$resourceGroupName,
    [string]$resource,
    [object[]]$listVms
  )

  $cost = 0
  $costUsd = 0
  $found = $false

  foreach($vm in $listVms) {
    if ($vm.ResourceGroupName -eq $resourceGroupName -and $vm.Resource -eq $resource) {
      $cost = $vm.Cost
      $costUsd = $vm.CostUSD
      $found = $true
      break
    }
  }
  return [Decimal]$cost, [Decimal]$costUsd, $found
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
  $objResult = @(
    [PSCustomObject]@{
      'SubscriptionName' = $listResult[0]
      'ResourceGroupName' = $listResult[1]
      'Resource' = $listResult[2]
      'ResourceType' = $listResult[3]
      'ResourceLocation' = $listResult[4]
      'Cost M-1' = $listResult[5]
      'Cost M' = $listResult[6]
      'Currency' = $listResult[7]
      'Cost USD M-1' = $listResult[8]
      'Cost USD M' = $listResult[9]
      'Cost Variation USD' = $listResult[10]
      'Variation in Percent USD' = $listResult[11]
    }
  )
  return $objResult
}
#
<# ------------------------------------------------------------------------
Main Program
--------------------------------------------------------------------------- #>
# Create directory results if not exists and filename for results
if ((CreateDirectoryResult $globalVar.workPath)) {
  # Create the CSV file result
  $csvResFile = (CreateFile -pathName $globalVar.workPath -fileName $globalVar.fileResult -extension 'csv' -chrono $globalVar.chronoFile)
  # if generateLogFile in Json file is set to "Y", create log file
  if ($globalVar.generateLogFile.ToUpper() -eq "Y") {
    # Create log file
    $globalLog = $true
    $logfile = (CreateFile -pathName $globalVar.workPath -fileName $globalVar.fileResult -extension 'log' -chrono $globalVar.chronoFile)
  }
}
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Starting processing...") }
Write-Host "INFO: Starting processing..."

$filePreviousMonth = $globalVar.workPath + $globalVar.filePreviousMonth
$fileCurrentMonth = $globalVar.workPath + $globalVar.fileCurrentMonth

if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Compare files $filePreviousMonth & $fileCurrentMonth.") }

$variationCost = @()

# Retrieve data from file M-1
$listPreviousMonth = Import-Csv -Path $filePreviousMonth -Delimiter "," | Where-Object -Property ResourceType -eq  $($globalVar.type) |
Select-Object -Property Resource, ResourceType, ResourceGroupName, ResourceLocation, SubscriptionName, Cost, CostUSD, Currency
# Retrieve data from file M
$listCurrentMonth = Import-Csv -Path $fileCurrentMonth -Delimiter "," | Where-Object -Property ResourceType -eq  $($globalVar.type) |
Select-Object -Property Resource, ResourceType, ResourceGroupName, ResourceLocation, SubscriptionName, Cost, CostUSD, Currency

$countResource = 0
foreach ($vm in $listPreviousMonth) {
  
  $costPrevMonth = [Decimal]$vm.Cost
  $costPrevMonthUsd = [Decimal]$vm.CostUSD
  
  # Search if VM in M-1 exists in M and retrieve costs
  ($cost, $costUsd, $found) = SearchResource -resourceGroupName $vm.ResourceGroupName -resource $vm.resource -listVms $listCurrentMonth
    
  # Calculate variation USD cost and Variation in percent
  $variationCostUsd = $costUsd - $costPrevMonthUsd
  $variationPercentUsd = (($costUsd - $costPrevMonthUsd)/$costPrevMonthUsd)*100
  
  $variationCost += SetObjResult @(
    $vm.SubscriptionName, $vm.ResourceGroupName, $vm.Resource, $vm.ResourceType, $vm.ResourceLocation,
    $costPrevMonth, $cost, $vm.Currency, $costPrevMonthUsd, $costUsd, $variationCostUsd, $variationPercentUsd
  )
  $countResource += 1
}

# Search new VMs that exist in M and not in M-1
foreach ($vm in $listCurrentMonth) {
  ($cost, $costUsd, $found) = SearchResource -resourceGroupName $vm.ResourceGroupName -resource $vm.resource -listVms $listPreviousMonth
  if (-not $found) {
    $variationCost += SetObjResult @(
      $vm.SubscriptionName, $vm.ResourceGroupName, $vm.Resource, $vm.ResourceType, $vm.ResourceLocation,
      0, 0, $vm.Currency, 0, $costUsd, $costUsd, 100
    )
    $countResource += 1
  }
}

# Write results in file
$variationCost | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
if ($globalLog) { 
  (WriteLog -fileName $logfile -message "INFO: End Processing...")
  (WriteLog -fileName $logfile -message "INFO: $countResource resources processed...")
  (WriteLog -fileName $logfile -message "the result file $csvResFile is available.") 
}
Write-Host "INFO: End Processing..."
Write-Host "INFO: $countResource resources processed..."
Write-Host "the result file $csvResFile is available."