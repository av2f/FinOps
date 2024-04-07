<#
  Name    : Get-AzOwnerSubscriptions.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 01/26/2024
  
  Updated date  : 04/07/2024
  Updated by    : Frederic Parmentier
  Update done   : Re-adapt script with new standards defined

  Retrieve Subscription owners from Access Control(IAM) and a Tag if defined and store them in 
  GetAzOwnerSubscriptions[mmddyyyyhhmmss].csv
  For more information, type Get-Help .\Get-AzOwnerSubscriptions.ps1 [-detailed | -full]

  Global variables are stored in .\GetAzOwnerSubscriptions.json and must be adapted accordingly
#>

<# -----------
  Declare input parameters
----------- #>
[cmdletBinding()]

param(
  [Parameter(Mandatory = $false)]
  [String]$TagOwner
)

# Disable breaking change Warning messages in Azure Powershell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

<# -----------
  Declare global variables, arrays and objects
----------- #>
# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path ".\GetAzOwnerSubscriptions.json" | ConvertFrom-Json
#
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

function CheckIfLogIn
{
  <#
    Check if already login to Azure
    If not the case, ask to login
    Input:
      - None
    Output:
      - $True
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

function CreateFile
{
  <#
    Create file with chrono with format : <filename>.MMddyyyyHHmmss
    Input:
      - $pathName: Path where create file
      - $fileName: File name
      - $extension: Extension of file to create
      - $chrono: Y|N - Specify if the file must be created with format $fileName.MMddyyyyHHmmss
    Output: 
      - $resFileName = File name accordingly options
    Use the variable $globalChronoFile to set up the chrono
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
        exit 1
      }
    }
    return $listSubscriptions
  }
}

function Get-TagOwner
{
  <#
    Retrieve the tag value as a parameter for a subscription
    Input :
      - $subscription : subscrption name for which the tag must be sought
      - $tagOwner : Tag name for which the value must be sought
    Output : Tag value. if not found, return '-'
  #>
  param(
    [Object[]]$subscription,
    [String]$tagOwner
  )
  # Retrieve Tags for the subsciption
  $tags = (Get-AzTag -ResourceID /subscriptions/$subscription)
  $tagValue = '-'
  foreach($tagKey in $tags.properties.TagsProperty.keys)
  {
    if($tagKey.ToLower() -eq $tagName.ToLower()){ 
      # $tagKey contains the tag Name
      $tagValue = $tags.Properties.TagsProperty[$tagKey]
    }
  }
  return $tagValue
}

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

<# -----------
  Main Program
----------- #>
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
# For Tests = Only Subcriptions that contains 'DXC'
# $subscriptions = Get-AzSubscription | Where-Object { ($_.Name -clike "*DXC*") -and ($_.State -eq "Enabled") }
# --

if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($subscriptions.Count) subscriptions found.") }
Write-Verbose "$($subscriptions.Count) subscriptions found."

# if there is at least 1 subscription, Analysis of each subscription
if ($subscriptions.Count -ne 0) {
  $ownerSubscriptions = @()
  foreach($subscription in $subscriptions)
  {
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Analysis of $($subscription.Name) Subscription...") }
    Write-Verbose "Analysis of $($subscription.Name) Subscription..."

    # if tag name declared, find matching value
    if ($TagOwner) {
      $tagValue = (Get-TagOwner -subscription $subscription -tagOwner $TagOwner)
      if ($tagValue -ne '-') {
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Tag Owner $($tagOwner) found with value $($tagValue)") }
        Write-Verbose "Tag Owner $($tagOwner) found with value $($tagValue)"
      }
      else {
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Tag Owner $($tagName) not found for this subscription.") }
        Write-Verbose "Tag Owner $($tagName) not found for this subscription."
      }
    }
    
    # Retrieve Owner(s) of the subscription
    $ownerAssignments, $countOwner = (Get-RoleOwnerSubscription -subscription $subscription)
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($countOwner) Owner(s) found for this subscription.") }
    Write-Verbose "$($countOwner) Owner(s) found for this subscription."
    Write-Verbose "---------------------" 
    # Create Object for result
    if($TagName)
    {
      $ownerResult=@(
        [PSCustomObject]@{
          SubscriptionName = $subscription.Name
          TagName = $tagName
          TagValue = $tagValue
          Owner = $ownerAssignments
        }
      )
    }
    else {
      $ownerResult=@(
        [PSCustomObject]@{
          SubscriptionName = $subscription.Name
          Owner = $ownerAssignments
        }
      )
    }
    # Add subscription result in result array
    $ownerSubscriptions += $ownerResult
  }
  # Generate the csv file
  $ownerSubscriptions | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: File $csvResFile is available.") }
  Write-Verbose "File $csvResFile is available."
}
else {
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: No Subscriptions enabled found.") }
  Write-Verbose "No Subscriptions enabled found."
}

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves Subscription owner(s) from Access Control (IAM) / Role Assignments and a tag if one is defined.
  
  .DESCRIPTION
  The script searches owner(s) of all subscriptions from IAM and a tag if one is defined and store it 
  in the file GetAzOwnerSubscriptions[mmddyyyyhhmmss].csv.
  The format of .csv file is :
  - if one tag defined : SubscriptionName;TagName;Tag_Value;Owner
  - if no tag defined : SubscriptionName;Owner
  
  Prerequisites :
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  .INPUTS
  Optional : -TagName <Tag_Name>. If one tag contains the owner, indicate this tag name.
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetAzOwnerSubscriptions[mmddyyyyhhmmss].csv file with results.

  .EXAMPLE
  .\Get-AzOwnerSubscriptions.ps1 : Retrieve Owner(s) in IAM.
  .\Get-AzOwnerSubscriptions.ps1 -TagName 'tag name' : Retrieve Owner(s) in both IAM and Tag Name specified.
  .\Get-AzOwnerSubscriptions.ps1 -Verbose : Execute the script without output progress informations on console.

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>