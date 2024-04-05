<#
  Name    : Get-AzAllTags.ps1
  Author  : Frederic Parmentier
  Version : 1.1
  Creation Date : 02/01/2024
  
  Updated date  : 04/05/2024
  Updated by    : F. Parmentier
  Update done   : 
    - Re-design script by functions
    - Add Json parameter file

  Retrieve Tags defined in Subscriptions, Resource Groups and Resources, and store them in 
  .\GetAzAllTags\GetAzAllTags[mmddyyyyhhmmss].csv
  For more information, type Get-Help .\Get-AzAllTags.ps1 [-detailed | -full]
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
$globalVar = Get-Content -Raw -Path ".\GetAzAllTags.json" | ConvertFrom-Json
#
$globalError = 0  # to count errors
$globalChronoFile = (Get-Date -Format "MMddyyyyHHmmss") # Format for file with chrono
$globalLog = $false # set to $true if generateLogFile in json file is set to "Y"

<# -----------
  Declare Functions
----------- #>
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
function CreateDirectoryResult
{
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

function GetTags
{
  <#
    Retrieve pair Tag Name / Tag Value
    Input :
      - subscription Id : subscription Id for which the tag must be sought
    Output : Hash Table with pair Tag Name / Tag Value
  #>
  param(
    [String]$subscriptionId
  )
  $tblTags = @{}
  # Retrieve Tags for the subsciption
  $tags = Get-AzTag -ResourceID /subscriptions/$subscriptionId
  if ($tags.Count -ne 0) {
    foreach($tagKey in $tags.properties.TagsProperty.keys){
      # $tagKey contains the tag Name  
      $tblTags.Add($tagKey, $tags.Properties.TagsProperty[$tagKey])
    }
  }
  return $tblTags
}
function SetObjResult {
  <#
    Create Object array with informations contained in the array $listResult
    Input: $listResult
    Output: Object array with informations
  #>
  param(
    [array] $listResult
  )
  if ($listResult.Count -ne 9) {
    $listResult=@('-', '-', '-', '-', '-', '-', '-', '-', '-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      SubscriptionName = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroup = $listResult[2]
      Resource = $listResult[3]
      ResourceType = $listResult[4]
      ResourceId = $listResult[5]
      Location = $listResult[6]
      TagName = $listResult[7]
      TagValue = $listResult[8]
    }
  )
  return $objTagResult
}

function GetSubscriptionTags
{
   <#
    Retrieve pair Tag Name / Tag Value
    Input :
      - subscription: subscription Name and ID for which the tag must be sought
    Output : Object Table with pair Tag Name / Tag Value
  #>
  param(
    [Object[]]$subscription
  )
  $subscriptionTags = @()
  $listTags = @()
  # Retrieve Tags for the subscription
  $listTags = (GetTags -subscriptionId $subscription.Id)
  # If there is at least 1 tag
  if ($listTags.Count -ne 0) {
    # Store each tags (key/value) in $subscriptionTags
    foreach ($key in $listTags.keys) {
      $subscriptionTags += (SetObjResult @($subscription.Name, $subscription.Id, '', '', 'Subscription', '', '', $key, $listTags[$key]))
    }
  }
  # Store empty line
  else{
    $subscriptionTags += SetObjResult @($subscription.Name, $subscription.Id, '', '', 'Subscription', '', '', '-', '-')
  }
  return $subscriptionTags
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

# =================== FAIRE LA GESTION DES SOUSCRIPTIONS EN FONCTION DE subscriptions dans json
# si "ALL" toutes les souscriptions, sinon fichier csv avec souscription name,souscription id
# retrieve Subscriptions enabled
# $subscriptions = Get-AzSubscription | Where-Object -Property State -eq "Enabled"
$subscriptions = Get-AzSubscription | Where-Object {($_.Name -clike "*DXC*") -and ($_.State -eq "Enabled")}
Write-Verbose "$($subscriptions.Count) subscriptions found."
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($subscriptions.Count) subscriptions found.") }
if ($subscriptions.Count -ne 0) {
  foreach ($subscription in $subscriptions) {
    # Initate array Result
    $arraySubscriptionTags = @()
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of the $($subscription.Name) subscription.") }
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    Set-AzContext -Subscription $subscription.Id
    # Retrieve subscription tags and write them in csv file
    $arraySubscriptionTags += (GetSubscriptionTags -subscription $subscription)
    $arraySubscriptionTags | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
    <# ------------
      ResourceGroup processing
    ------------ #>
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resource Groups from $($subscription.Name)") }
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroupNames = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName, Location, Tags, ResourceId | Sort-Object Location, ResouceGroupName)
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($resourceGroupNames.Count) Resource Groups found") }
    Write-Verbose "-- $($resourceGroupNames.Count) Resource Groups found"
    if ($resourceGroupNames.Count -ne 0) {
      foreach ($resourceGroupName in $resourceGroupNames) {
        $objRgResult = @()
        $arrayRgTags = @()
        # Retrives Tags
        if ($resourceGroupName.Tags.Count -ne 0) {
          foreach ($key in $resourceGroupName.Tags.keys) {
            $objRgResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, '', 'Resource Group', $resourceGroupName.ResourceId, $resourceGroupName.Location, $key, $resourceGroupName.Tags[$key])
          }
        }
        else {
          $objRgResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, '', 'Resource Group', $resourceGroupName.ResourceId, $resourceGroupName.Location, '-', '-')
        }
        <# ------------
          Resources processing
        ------------ #>
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resources from Resource Group $($resourceGroupName.ResourceGroupName)") }
        Write-Verbose "--- Processing of Resources from Resource Group $($resourceGroupName.ResourceGroupName)"
        $resources = (Get-AzResource -ResourceGroupName $resourceGroupName.ResourceGroupName | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags | Sort-Object Location, Name)
        Write-Verbose "--- $($resources.Count) Resource found"
        if ($resources.Count -ne 0) {
          foreach ($resource in $resources) {
            # Retrives Tags
            if ($resource.Tags.Count -ne 0) {
              foreach ($key in $resource.Tags.keys) {
                $objRgResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, $resource.Name, $resource.ResourceType, $resource.ResourceId, $resource.Location, $key, $resource.Tags[$key])
              }
            }
            else{
              $objRgResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, $resource.Name, $resource.ResourceType, $resource.ResourceId, $resource.Location, '-', '-')
            }
          }
        }
        $arrayRgTags += $objRgResult
        $arrayRgTags | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
      }
    }
    $arraySubTags += $objSubResult
    $arraySubTags | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
    Write-Verbose "---------------------------------------------"
  }
}
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: File $csvResFile is available.") }
Write-Verbose "File $csvResFile is available."
if ($globalLog) {
  (WriteLog -fileName $logfile -message "INFO: End processing with $globalError error(s)...") 
}

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves all Tags defined in Subscriptions, Resource Groups and Resources.

  .DESCRIPTION
  The Get-AllTags script searches all Tags defined in Subscriptions, Resource Groups and Resources; and store them 
  in the file .\GetAzAllTags\GetAzAllTagsMMddyyyyHHmmss.csv.
  The format of .csv file is :
  SubscriptionName;SubscriptionId;ResourceGroup;Resource;ResourceId;Location;TagName;TagValue
  
  Prerequisites :
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  .INPUTS
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetAzAllTagsMMddyyyyHHmmss.csv file with results.

  .EXAMPLE
  .\Get-AzAllTags.ps1
  .\Get-AzAllTags.ps1 -Verbose : Execute script writing on console progress informations.
  

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>
