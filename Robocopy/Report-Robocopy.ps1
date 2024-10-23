<#
  Name    : Report-Robocopy.ps1
  Author  : Frederic Parmentier
  Version : 0.9
  Creation Date : 10/23/2024
 
   
  For more information, type Get-Help .\Report-Robocopy.ps1 [-detailed | -full]

  Global variables are stored in .\Report-Robocopy.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Report-Robocopy.json" | ConvertFrom-Json

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
function GetLogFiles
{
  <#
    Retrieve log files and assign to $robocopyLogs
    Input:
      - $pathLogFiles: Directory where log files are stored
      - $logFileName: name of log file
    Output: 
      - $robocopyLogs: list of log files
      - if $pathLogFiles is not found, exit with error code 1
  #>
  param(
    [string]$pathLogFiles,
    [string]$logFileName
  )
  if ((Test-Path -Path $pathLogFiles) -eq $true) {
    # Retrieve all log files
    $filterFile = $logFileName + '*.log'
    $robocopyLogs = Get-ChildItem -Path $globalVar.logFiles -File -Filter $filterFile | Select-Object -ExpandProperty Name
  }
  else {
    # if logs directory does not exist, end script
    if ($globalLog) { (WriteLog -fileName $logfile -message "ERROR: the directory $($pathLogFiles) does not exit. Ensure the directory is set up correctly.") }
    exit 1
  }
  return $robocopyLogs
}

#
<# ------------------------------------------------------------------------
Main Program
--------------------------------------------------------------------------- #>
# Create directory results if not exists and filename for results
if ((CreateDirectoryResult $globalVar.pathResult)) {
  # Create the CSV file result
  $csvResFile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'csv' -chrono $globalVar.chronoFile)
  # Create the temp Robocopy log file
  $tmpRobocopyLog = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.tmpRobocopyLog -extension 'log' -chrono $globalVar.chronoFile)
  # if generateLogFile in Json file is set to "Y", create log file
  if ($globalVar.generateLogFile.ToUpper() -eq "Y") {
    # Create log file
    $globalLog = $true
    $logFile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'log' -chrono $globalVar.chronoFile)
  }
}
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Starting processing...") }
Write-Verbose "Starting processing..."


# Read Robocopy logs

$robocopyLogs = GetLogFiles -pathLogFiles $globalVar.logFiles -logFileName $globalVar.robocopyLog
if (($robocopyLogs | Measure-Object).Count -gt 0) {
  foreach($robocopyLog in $robocopyLogs) {
    Write-Host $robocopyLog
  }
}
else {
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: No log files found. Stop processing...") }
  exit 0
}



<#
# robocopy 'C:\Users\fparment\Documents\Dossiers Clients' 'C:\Users\fparment\Documents\testrobocopy' /e /unilog:robocopy.log /np /bytes /v /MIR



# read $logFile removing blank lines with result in tempLog
Get-Content $logfile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Set-Content $tempLog
$arrayLog = Get-Content $tempLog

foreach ($line in $arrayLog) {
  write-host $line
}

write-host ($arrayLog | Measure-Object).Count


# Penser a supprimer $templog

# Recuperer la liste des fichiers
# Get-ChildItem -Path "C:/Users/fparment/Documents/AzFinOps/Scripts/Robocopy/Logs/" -File -Filter "logRobocopy*.log" | Select -ExpandProperty Name
#>