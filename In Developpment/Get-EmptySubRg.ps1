<#
  Name    : Get-EmptySubRg.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 02/22/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Retrieve Empty subscriptions and Resources Groups
  .\GetEmptySubRg\GetEmptySuRgmmddyyyyhhmmss.csv
  For more information, type Get-Help .\Get-EmptySubRg.ps1 [-detailed | -full]
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
# Initiate result array
$arrayAllTags = @()

<# -----------
  Declare Functions
----------- #>
function CreateDirectoryResult{
  <#
    Create Directory to store result files if not already existing
    Input :
      - $directory : directory name to create if not already existing
    Output : 
      - $True
  #>
  param(
    [String] $directory
  )
  if((Test-Path -Path $directory) -eq $False){
    New-Item -Path . -Name $directory -ItemType "Directory"
  }
  return $True
}
function CreateChronoFile
{
  <#
    Create file with chrono with format : <filename>.MMddyyyyHHmmss
    Input :
      - $fileName : File name to create chrono file 
    Output : 
      - File name with format $fileName.MMddyyyyHHmmss
  #>
  param(
    [String] $fileName
  )
  $chrono = Get-Date -Format "MMddyyyyHHmmss"
  $fileName += $chrono
  return $fileName
}

function GetTags
{
  <#
    Retrieve pair Tag Name / Tag Value
    Input :
      - subscription : subscrption name for which the tag must be sought
    Output : Hash Table with pair Tag Name / Tag Value
  #>
  param(
    [Object[]] $subscription
  )
  $tblTags = @{}
  # Retrieve Tags for the subsciption
  $tags = Get-AzTag -ResourceID /subscriptions/$subscription
  if ($tags.Count -gt 0) {
    foreach($tagKey in $tags.properties.TagsProperty.keys){
      # $tagKey contains the tag Name  
      $tblTags.Add($tagKey, $tags.Properties.TagsProperty[$tagKey])
    }
  }
  return $tblTags
}
function SetObjResult {
  <#
    $listResult must contains 9 elements
  #>
  param(
    [array] $listResult
  )
  if($listResult.Count -ne 7){
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
    }
  )
  return $objTagResult
}

<# -----------
  Main Program
----------- #>
# Create file name
if((CreateDirectoryResult 'GetEmptySubRg')){
  $csvFile = '.\GetEmptySubRg\' + (CreateChronoFile 'GetEmptySubRg') + '.csv'
}
Write-Verbose "Starting processing..."
$nbEmptySub = 0
$nbEmptyRg = 0
# retrieve Subscriptions enabled
$subscriptions = Get-AzSubscription | Where-Object -Property State -eq "Enabled"
Write-Verbose "$($subscriptions.Count) subscriptions found."
if($subscriptions.Count -gt 0){
  foreach($subscription in $subscriptions){
    <# ------------
      Subscription processing
    ------------ #>
    $objResult = @()
    $arrayAllTags = @()
    # Set the context to use the specified subscription
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    Set-AzContext -Subscription $subscription
    <# ------------
      ResourceGroup processing
    ------------ #>
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroupNames = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName, Location, Tags, ResourceId | Sort-Object Location, ResouceGroupName)
    Write-Verbose "-- $($resourceGroupNames.Count) Resource Groups found"
    if($resourceGroupNames.Count -eq 0){
      # if no resource groups, store the subscription
      $objResult += SetObjResult @($subscription.Name, $subscription.Id, '', '', 'Subscription', '', '')
      $nbEmptySub +=1
    }
    else {
      # Scan resource groups from subscription
      foreach($resourceGroupName in $resourceGroupNames){
        <# ------------
          Resource processing
        ------------ #>
        Write-Verbose "--- Processing of Resources from Resource Group $($resourceGroupName.ResourceGroupName)"
        $resources = (Get-AzResource -ResourceGroupName $resourceGroupName.ResourceGroupName | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags | Sort-Object Location, Name)
        Write-Verbose "--- $($resources.Count) Resource found"
        if($resources.Count -eq 0){
          $objResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, '', 'Resource Group', $resourceGroupName.ResourceId, $resourceGroupName.Location)
          $nbEmptyRg += 1
        }
      }
    }
    $arrayAllTags += $objResult
    $arrayAllTags | Export-Csv -Path $csvFile -Delimiter ";" -NoTypeInformation -Append
    Write-Verbose "---------------------------------------------"
  }
}

Write-Verbose "File $csvFile is available."
Write-Verbose "$nbEmptySub Subscriptions found."
Write-Verbose "$nbEmptyRg Resource Groups found."

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves all Tags defined in Subscriptions, Resource Groups and Resources.

  .DESCRIPTION
  The Get-AllTags script searches all Tags defined in Subscriptions, Resource Groups and Resources; and store them 
  in the file .\GetAllTags\GetAllTagsMMddyyyyHHmmss.csv.
  The format of .csv file is :
  SubscriptionName;SubscriptionId;ResourceGroup;Resource;ResourceId;Location;TagName;TagValue
  
  Prerequisites :
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  .INPUTS
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetAllTagsMMddyyyyHHmmss.csv file with results.

  .EXAMPLE
  .\Get-AllTags.ps1
  .\Get-AllTags.ps1 -Verbose : Execute script writing on console progress informations.
  

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>
