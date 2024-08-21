<#
  Name    : Get-AzCostVariation.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 08/19/2024
  
  Compare costs of resources between M-1 and M and calculate USD Cost Variation and variation in percentage.
  
  Global variables are stored in .\Get-AzCostVariation.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzCostVariation.json" | ConvertFrom-Json
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
    Search if resource $resource in the Resource Group $resourceGroupName and type of resource $resourceType exists in $listResources
    Input:
      - $resourceId: Resource Id
      - $listResources: List of of resources
    Output: 
      - $cost: Cost in Decimal format of the VM
      - $Found: Boolean. $true if VM has been found, else return $false.
  #>
  param(
    [string]$resourceId,
    [object[]]$listResources
  )

  $cost = 0
  $found = $false
  
  foreach($res in $listResources) {
    if ($res.ResourceId -eq $resourceId) {
      $cost = $res.Cost
      $found = $true
      break
    }
  }

  return [Decimal]$cost, $found
}

function GetResourceId()
{
  <#
    Search if resource $resource in the Resource Group $resourceGroupName and type of resource $resourceType exists in $listResources
    Input:
      - $resourceType: type of resource to search defined in the Json file parameter
      - $listResources: List of resources
    Output: 
      - $resourcesId: list of Resource ID filtered following the type
  #>
  param(
    [string]$resourceType,
    [object[]]$listResources
  )

  $resourcesId = @()

  if ($resourceType.ToLower() -ne "all") {
    $listTypes = $resourceType.split(",")
  }

  foreach ($resource in $listResources) {
    if ($resourceType.ToLower() -eq "all") {
      $resourcesId += $resource.ResourceId
    }
    elseif ($resource.ResourceType -cin $listTypes) {
      $resourcesId += $resource.ResourceId
    }
  }

  return $resourcesId
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
  if ($listResult.Count -ne 10) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-')
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
      'Cost Variation' = $listResult[8]
      'Variation in Percent' = $listResult[9]
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
if (-not (Test-Path $filePreviousMonth -PathType leaf)) {
  if ($globalLog) { (WriteLog -fileName $logfile -message "Error: the file $filePrevious is not available.") }
  Write-Host "Error: the file $filePrevious is not available."
  exit 1
}

$fileCurrentMonth = $globalVar.workPath + $globalVar.fileCurrentMonth
if (-not (Test-Path $fileCurrentMonth -PathType leaf)) {
  if ($globalLog) { (WriteLog -fileName $logfile -message "Error: the file $fileCurrentMonth is not available.") }
  Write-Host "Error: the file $fileCurrentMonth is not available."
  exit 1
}

if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Compare files $filePreviousMonth & $fileCurrentMonth.") }

$variationCost = @()
$resourceIdPreviousMonth = @()
$resourceIdCurrentMonth = @()

# Retrieve data from file M-1
$listPreviousMonth = Import-Csv -Path $filePreviousMonth -Delimiter "," | Select-Object -Property Resource, ResourceId, ResourceType,
ResourceGroupName, ResourceLocation, SubscriptionName, Cost, Currency
# Retrieve data from file M
$listCurrentMonth = Import-Csv -Path $fileCurrentMonth -Delimiter "," | Select-Object -Property Resource, ResourceId, ResourceType,
ResourceGroupName, ResourceLocation, SubscriptionName, Cost, Currency

# Retrieves Resources ID of previous month following types defined in the json file parameter
$resourceIdPreviousMonth = GetResourceId -listResources $listPreviousMonth -resourceType $globalVar.type
# Retrieves Resources ID of current month following types defined in the json file parameter
$resourceIdCurrentMonth = GetResourceId -listResources $listCurrentMonth -resourceType $globalVar.type

$countResource = 0
foreach ($resource in $resourceIdPreviousMonth) {
  
  $resourceIdPreviousMonth = $listPreviousMonth | Where-Object -Property ResourceId -eq $resource |
  Select-Object -Property Resource, ResourceId, ResourceType, ResourceGroupName, ResourceLocation, SubscriptionName, Cost, Currency
  
  $costPrevMonth = [Decimal]$resourceIdPreviousMonth.Cost

  # Search if resource in M-1 exists in M and retrieve costs
  ($cost, $found) = SearchResource -resourceId $resource -listResources $listCurrentMonth

  # Calculate variation cost and Variation in percent
  [Decimal]$varCost = $cost - $costPrevMonth
  $varPercent = ""
  if ($costPrevMonth -gt 0) {
    [Decimal]$varPercent = (($cost - $costPrevMonth)/$costPrevMonth)*100
  }
  
  $variationCost += SetObjResult @(
    $resourceIdPreviousMonth.SubscriptionName, $resourceIdPreviousMonth.ResourceGroupName, $resourceIdPreviousMonth.Resource, $resourceIdPreviousMonth.ResourceType,
    $resourceIdPreviousMonth.ResourceLocation, $costPrevMonth, $cost, $resourceIdPreviousMonth.Currency, $varCost, $varPercent
  )
  $countResource += 1
}

# Search new VMs that exist in M and not in M-1
foreach ($resource in $resourceIdCurrentMonth) {

  $resourceIdCurrentMonth = $listCurrentMonth | Where-Object -Property ResourceId -eq $resource |
  Select-Object -Property Resource, ResourceId, ResourceType, ResourceGroupName, ResourceLocation, SubscriptionName, Cost, Currency

  ($cost, $found) = SearchResource -resourceId $resource -listResources $listPreviousMonth
  if (-not $found) {
    $variationCost += SetObjResult @(
      $resourceIdCurrentMonth.SubscriptionName, $resourceIdCurrentMonth.ResourceGroupName, $resourceIdCurrentMonth.Resource,
      $resourceIdCurrentMonth.ResourceType, $resourceIdCurrentMonth.ResourceLocation,
      0, $resourceIdCurrentMonth.Cost, $resourceIdCurrentMonth.Currency, $resourceIdCurrentMonth.Cost, ""
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