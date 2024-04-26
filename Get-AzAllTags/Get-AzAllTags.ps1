<#
  Name    : Get-AzAllTags.ps1
  Author  : Frederic Parmentier
  Version : 1.2
  Creation Date : 02/01/2024

  Retrieve Tags defined in Subscriptions, Resource Groups and Resources, and store them in 
  .\GetAzAllTags\GetAzAllTags[mmddyyyyhhmmss].csv
  For more information, type Get-Help .\Get-AzAllTags.ps1 [-detailed | -full]
  Global variables are stored in .\GetAzAllTags.json and must be adapted accordingly
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
$globalChronoFile = (Get-Date -Format "MMddyyyyHHmmss") # Format for file with chrono
$globalLog = $false # set to $true if generateLogFile in json file is set to "Y"
# Create Array with FinOps Tags
$finOpsTags = $globalVar.finOpsTags.split(",")

<# -----------
  Declare Functions
----------- #>
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

function CreateExcelFile
{
  <#
   Create an Excel file with the result csv files
    Input:
      - $excelFileName: Excel file name
      - $csvFiles: Array of csv files with WorkSheetName
        format: WorksheetName:CsvFileName
      - $removeCsvFile: If set to $true, remove csv files after the export in the Excel file
    Output: 
      - the Excel file $excelFileName
  #>
  param(
    [string]$excelFileName,
    [hashtable]$csvFiles,
    [boolean]$removeCsvFile
  )
  
  # Create Excel File and Remove csv files if $removeCsvFile is set to True
  foreach($key in $csvFiles.Keys) {
    Import-Csv -Path $csvFiles[$key] | Export-Excel -Path $excelFileName -WorkSheetName $key
    if ($removeCsvFile) {
      if (Test-Path -Path $csvFiles[$key] -PathType Leaf)
      {
        Remove-Item -Path $csvFiles[$key] -Force
      }
    }
  }
}

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
  if ($listResult.Count -ne 12) {
    $listResult=@('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-')
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
      Status = $listResult[7]
      NbOfMissingFinOpsTags = $listResult[8]
      MissingFinOpsTags = $listResult[9]
      TagsNameDefined = $listResult[10]
      TagsDefined = $listResult[11]
    }
  )
  return $objTagResult
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

function SearchFinOpsTags {

  param (
    [Array]$listTags,
    [Array]$finOpsTags
  )

  $arrayMissingFinOpsTags = @()
  $missingFinOpsTags = ""
  $missing = $false
  $nbOfMissingFinOpsTags = 0

  foreach ($finOpsTag in $finOpsTags) {
    if ($finOpsTag -cnotin $listTags) {
      $arrayMissingFinOpsTags += $finOpsTag
      $nbOfMissingFinOpsTags += 1
    }
  }
  if ($arrayMissingFinOpsTags.Count -gt 0) {
    $missingFinOpsTags = "{" + ($arrayMissingFinOpsTags -join ",") + "}"  
    $missing = $true
  }
  return $missing,$nbOfMissingFinOpsTags,$missingFinOpsTags
}

function GetSubscriptionTags
{
   <#
    Retrieve pair Tag Name / Tag Value for subcriptions
    Input :
      - $subscription: Object table of subscription for which tags must be sought
    Output:
      - Object Table with pair Tag Name / Tag Value
  #>
  param(
    [Object[]]$subscription,
    [Array]$finOpsTags
  )
  
  $tagsJson = ""
  $tags = @{}
  $subscriptionTags = @()
  $listSubscriptionTags = @()
  $listTags = @()
  $status = "FinOps tags present"
  $listMissingFinOpsTags = ""
  $listTagsName = "{}"
  $NumberOfMissingFinOpsTags = $finOpsTags.Count

  # Retrieve Tags for the subscription
  $listSubscriptionTags = (GetTags -subscriptionId $subscription.Id)
  # If there is at least 1 tag
  if ($listSubscriptionTags.Count -ne 0) {
    # Store each tags (key/value) in $subscriptionTags
    foreach ($key in $listSubscriptionTags.keys) {
      # Add Tags to Hash array
      $tags.Add($key, $listSubscriptionTags[$key])
      $listTags += $key
    }
    # Check if FinOps tags are present
    $listTags = $listTags | Sort-Object
    $listTagsName = "{" + ($listTags -join ",") + "}"
    $missingFinOpsTags,$nbOfMissingFinOpsTags,$listMissingFinOpsTags = (SearchFinOpsTags -listTags $listTags -finOpsTags $finOpsTags)
    if ($missingFinOpsTags) {
      # Some FinOps tags are missing
      $status = "Missing FinOps tags"
      $NumberOfMissingFinOpsTags = $nbOfMissingFinOpsTags
    }
    else {
      # All FinOps Tags are present
      $NumberOfMissingFinOpsTags = 0
    }
  }
  # Store empty line
  else{
    $status = "No tags defined"
    $tags.Add("Tag", "Empty")
  }
  # Convert hash array into Json
  $tagsJson = $tags | ConvertTo-Json -Compress
  # Add to result object array
  $subscriptionTags += (
    SetObjResult @($subscription.Name, $subscription.Id, '', '', 'Subscription',
    '', '', $status,
    $NumberOfMissingFinOpsTags, $listMissingFinOpsTags, $listTagsName, $tagsJson)
  )
  return $subscriptionTags
}

function GetResourceGroupTags
{
  <#
    Retrieve pair Tag Name / Tag Value for resource groups
    Input :
      - $subscription: subscription of the resource Group
      - $resourceGroup: Object table that contains resource group informations for which tags must be sought
      - $finOpsTags: List of FinOpsTags defined
    Output:
      - Object Table with pair Tag Name / Tag Value
  #>
  param(
    [Object[]]$subscription,
    [Object[]]$resourceGroup,
    [Array]$finOpsTags
  )
  
  $tagsJson = ""
  $tags = @{}
  $resourceGroupTags = @()
  $listTags = @()
  $status = "FinOps tags present"
  $listMissingFinOpsTags = ""
  $listTagsName = "{}"
  $NumberOfMissingFinOpsTags = $finOpsTags.Count
  
  if ($resourceGroup.Tags.Count -ne 0) {
    foreach ($key in $resourceGroup.Tags.keys) {
      $tags.Add($key, $resourceGroup.Tags[$key])
      $listTags += $key
    }
    # Check if FinOps tags are present
    $listTags = $listTags | Sort-Object
    $listTagsName = "{" + ($listTags -join ",") + "}"
    $missingFinOpsTags,$nbOfMissingFinOpsTags,$listMissingFinOpsTags = (SearchFinOpsTags -listTags $listTags -finOpsTags $finOpsTags)
    if ($missingFinOpsTags) {
      # Some FinOps tags are missing
      $status = "Missing FinOps tags"
      $NumberOfMissingFinOpsTags = $nbOfMissingFinOpsTags
    }
    else {
      # All FinOps Tags are present
      $NumberOfMissingFinOpsTags = 0
    }
  }
  else {
    $status = "No tags defined"
    $tags.Add("Tag", "Empty")
  }
  # Convert hash array into Json
  $tagsJson = $tags | ConvertTo-Json -Compress
  # Add to result object array
  $resourceGroupTags += (
    SetObjResult @($subscription.Name, $subscription.Id, $resourceGroup.ResourceGroupName, '', 'Resource Group',
    $resourceGroup.ResourceId, $resourceGroup.Location, $status,
    $NumberOfMissingFinOpsTags, $listMissingFinOpsTags, $listTagsName, $tagsJson)
  )
  return $resourceGroupTags
}

function GetResourceTags 
{
  <#
    Retrieve pair Tag Name / Tag Value for resources
    Input :
      - $subscription: Subscription of the resource group
      - $resourceGroupName: Resource Group name of resource
      - $resource: Object that contains resource informations for which tags must be sought
      - $finOpsTags: List of FinOpsTags defined
    Output:
      - Object Table with pair Tag Name / Tag Value
  #>
  param(
    [Object[]]$subscription,
    [String]$resourceGroupName,
    [Object[]]$resource,
    [Array]$finOpsTags
  )
  
  $tagsJson = ""
  $tags = @{}
  $resourceTags = @()
  $listTags = @()
  $status = "FinOps tags present"
  $listMissingFinOpsTags = ""
  $listTagsName = "{}"
  $NumberOfMissingFinOpsTags = $finOpsTags.Count

  if ($resource.Tags.Count -ne 0) {
    foreach ($key in $resource.Tags.keys) {
      $tags.Add($key, $resource.Tags[$key])
      $listTags += $key
    }
    # Check if FinOps tags are present
    $listTags = $listTags | Sort-Object
    $listTagsName = "{" + ($listTags -join ",") + "}"
    $missingFinOpsTags,$nbOfMissingFinOpsTags,$listMissingFinOpsTags = (SearchFinOpsTags -listTags $listTags -finOpsTags $finOpsTags)
    if ($missingFinOpsTags) {
      # Some FinOps tags are missing
      $status = "Missing FinOps tags"
      $NumberOfMissingFinOpsTags = $nbOfMissingFinOpsTags
    }
    else {
      # All FinOps Tags are present
      $NumberOfMissingFinOpsTags = 0
    }
  }
  else{
    $status = "No tags defined"
    $tags.Add("Tag", "Empty")
  }
  # Convert hash array into Json
  $tagsJson = $tags | ConvertTo-Json -Compress
  # Add to result object array
  $resourceTags += SetObjResult @(
    $subscription.Name, $subscription.Id, $resourceGroupName, $resource.Name, $resource.ResourceType,
    $resource.ResourceId, $resource.Location, $status,
    $NumberOfMissingFinOpsTags, $listMissingFinOpsTags, $listTagsName, $tagsJson
  )
  return $resourceTags
}

#
<# ------------------------------------------------------------------------
Main Program
--------------------------------------------------------------------------- #>
# Create directory results if not exists and filename for results
if ( (CreateDirectoryResult $globalVar.pathResult) ) {
  # Create csv result file
  $csvFileResult = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'csv' -chrono $globalVar.chronoFile)
  
  # if generateLogFile in Json file is set to "Y", create log file
  if ($globalVar.generateLogFile.ToUpper() -eq "Y") {
    # Create log file
    $globalLog = $true
    $logfile = (CreateFile -pathName $globalVar.pathResult -fileName $globalVar.fileResult -extension 'log' -chrono $globalVar.chronoFile)
  }
}
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Starting processing...") }
Write-Verbose "Starting processing..."

# Check if saveEvery in Json file parameter is >= 10
CheckSaveEvery -saveEvery $globalVar.saveEvery

# if variable checkIfLogIn in json file is set to "Y", Check if log in to Azure
if ($globalVar.checkIfLogIn.ToUpper() -eq "Y") { CheckIfLogIn }

# retrieve Subscriptions
$subscriptions = (GetSubscriptions -scope $globalVar.subscriptionsScope)
Write-Verbose "$($subscriptions.Count) subscriptions found."
if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($subscriptions.Count) subscriptions found.") }
if ($subscriptions.Count -ne 0) {
  foreach ($subscription in $subscriptions) {
    # Initate arrays Result
    $arrayTags = @()
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of the $($subscription.Name) subscription.") }
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    Set-AzContext -Subscription $subscription.Id
    # Retrieve subscription tags and write in result file
    $arrayTags = (GetSubscriptionTags -subscription $subscription -finOpsTags $finOpsTags)
    $arrayTags | Export-Csv -Path $csvFileResult -Delimiter ";" -NoTypeInformation -Append

    <# ------------
      ResourceGroup processing
    ------------ #>
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resource Groups from $($subscription.Name)") }
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroups = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName, Location, Tags, ResourceId | Sort-Object Location, ResouceGroupName)
    # As there is a bug with .Count when only 1 resource group, replace by "$resourceGroups | Measure-Object | ForEach-Object count"
    $resourceGroupsCount = $resourceGroups | Measure-Object | ForEach-Object Count
    if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($resourceGroupsCount) Resource Groups found") }
    Write-Verbose "-- $($resourceGroupsCount) Resource Groups found"
    
    if ($resourceGroupsCount -ne 0) {
      foreach ($resourceGroup in $resourceGroups) {
        $arrayTags = @()
        # Retrieve resource group Tags and write in result file
        $arrayTags = (GetResourceGroupTags -subscription $subscription -ResourceGroup $resourceGroup -finOpsTags $finOpsTags)
        $arrayTags | Export-Csv -Path $csvFileResult -Delimiter ";" -NoTypeInformation -Append
        <# ------------
          Resources processing
        ------------ #>
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Processing of Resources from Resource Group $($resourceGroup.ResourceGroupName)") }
        Write-Verbose "--- Processing of Resources from Resource Group $($resourceGroup.ResourceGroupName)"
        $resources = (Get-AzResource -ResourceGroupName $resourceGroup.ResourceGroupName | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags | Sort-Object Location, Name)
        # As there is a bug with .Count when only 1 resource, replace by "$resources | Measure-Object | ForEach-Object count"
        $numberOfResources = $($resources | Measure-Object | ForEach-Object count)
        
        if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: $($numberOfResources) Resources found") }
        Write-Verbose "--- $($numberOfResources) Resources found"
        
        if ($numberOfResources -ne 0) {
          $arrayTags = @()
          $countResource = 0
          foreach ($resource in $resources) {
            $arrayTags += (GetResourceTags -subscription $subscription -resourceGroupName $resourceGroup.ResourceGroupName -resource $resource -finOpsTags $finOpsTags)
            $countResource += 1
            # if number of resources = SaveEvery in json file parameter, write in the result file and re-initiate the array and counter
            if ($countResource -eq $globalVar.saveEvery) {
              if ($arrayTags.Count -gt 0) {$arrayTags | Export-Csv -Path $csvFileResult -Delimiter ";" -NoTypeInformation -Append }
              $arrayTags = @()
              $countResource = 0
            }
          }
          # Write last resources
          if ($countResource -gt 0) {
            $arrayTags | Export-Csv -Path $csvFileResult -Delimiter ";" -NoTypeInformation -Append
          }
        }
      }
    }
    Write-Verbose "---------------------------------------------"
  }
  <#
  # Build Excel file with results
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: Building Final Excel file results...") }
  Write-Verbose "Building Final Excel file results..."
  $csvFileToExcel = @{}
  $csvFileToExcel.Add("AzTags", $csvFileTags)
  $csvFileToExcel.Add("AzNoTags", $csvFileNoTags)
  CreateExcelFile -excelFileName $xlsResFile -csvFiles $csvFileToExcel -removeCsvFile $false
  #>

  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: File $csvFileResult is available.") }
  Write-Verbose "File $csvFileResult is available."
}
else {
  if ($globalLog) { (WriteLog -fileName $logfile -message "INFO: No Subscriptions enabled found.") }
  Write-Verbose "No Subscriptions enabled found."
}
if ($globalLog) {
  (WriteLog -fileName $logfile -message "INFO: End processing...") 
}

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves all pairs Key/Value Tags defined in Subscriptions, Resource Groups and Resources.

  .DESCRIPTION
  The Get-AzAhb script creates the GetAzAhb[mmddyyyyhhmmss].csv file retrieving informations below for each Windows VMs:
  - Subscription Name
  - Subscription ID
  - Resource Group Name
  - Resource Name
  - Resource Type
  - Resource ID
  - Location
  - Tag Name (Key)
  - Tag Value
  
  Prerequisites :
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  Parameters: GetAzAhb.json file
  the GetAzAllTags.json file allows to adapt script to context.
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

  - finOpsTags: List of FinOps Tags with format: "tag1,tag2,tag2,tagn..."

  - subscriptionsScope: 
    - scope: All|.csv file
      - if you set "All", process all subscription
      - if you set a .csv file, process subscriptions in file
        + format must be: 
          - 1st column : Subscription Name with column named "Name"
          - 2nd column : Subscription Id with column name "Id"
        + example: "scope": "C:/data/subscriptions.csv"
    - delimiter: indicate the delimiter in the .csv file

  - saveEvery: Indicates how many resources should be written at the same time to the result file
    - by default value is 100 and minimum tolerated value is 10
    - If you have less memory available, reduce the value.

  .INPUTS
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetAzAllTags[MMddyyyyHHmmss].csv file with results.
  Optional: GetAzAllTags[MMddyyyyHHmmss].log file with detailed log.

  .EXAMPLE
  .\Get-AzAllTags.ps1
  .\Get-AzAllTags.ps1 -Verbose : Execute script writing on console progress informations.
  

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>
