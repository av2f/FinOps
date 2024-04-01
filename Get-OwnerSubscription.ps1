<#
  Name    : Get-OwnerSubscription.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 01/26/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Retrieve Subscription owners from Access Control(IAM) and a Tag if defined and store them in 
  .\GetOwnerSubscription\GetOwnerSubscriptionmmddyyyyhhmmss.csv
  For more information, type Get-Help .\Get-OwnerSubscription.ps1 [-detailed | -full]
#>

<# -----------
  Declare input parameters
----------- #>
[cmdletBinding()]

param(
  [Parameter(Mandatory = $false)]
  [String]$TagName
)

# Disable breaking change Warning messages in Azure Powershell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

<# -----------
  Declare global variables, arrays and objects
----------- #>
# Initiate result array
$arraySubscriptionOwner = @()

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
  param(
    [String] $fileName
  )
  $chrono = Get-Date -Format "MMddyyyyHHmmss"
  $fileName += $chrono
  return $fileName
}
function Get-TagOwner
{
  <#
    Retrieve the tag value as a parameter for a subscription
    Input :
      - fSubscription : subscrption name for which the tag must be sought
      - $fTagName : Tag name for which the value must be sought
    Output : Tag value. if not found, return '-'
  #>
  param(
    [Object[]] $fSubscription,
    [String] $fTagName
  )
  # Retrieve Tags for the subsciption
  $tags = Get-AzTag -ResourceID /subscriptions/$fsubscription
  $fTagValue = '-'
  foreach($tagKey in $tags.properties.TagsProperty.keys)
  {
    if($tagKey.ToLower() -eq $ftagName.ToLower()){ 
      # $tagKey contains the tag Name
      $ftagValue = $tags.Properties.TagsProperty[$tagKey]
    }
  }
  return $ftagValue
}

function Get-RoleOwnerSubscription
{
  <#
    Retrieve the owner(s) declared in IAM for a subscription
    Input :
      - fSubscription : subscrption name for which the owner(s) must be sought
    Output : 
      - $stOwnerAssignment : String which contains owner(s) with format : Owner1_name[Type]-Owner2_name[Type]-...
      - $count : Number of Owner found
  #>
  param(
    [Object[]] $fSubscription
  )
  $strOwnerAssignment = ''
  $roleAssignments = Get-AzRoleAssignment -Scope /subscriptions/$fsubscription | Where-Object {$_.RoleDefinitionName -eq 'Owner'} | Select-Object -Property DisplayName, ObjectType
  $count = $roleAssignments.count
  if($count -gt 0)
  {
    foreach($roleAssignment in $roleAssignments)
    {
      $stOwner = $roleAssignment.DisplayName + '[' + $roleAssignment.ObjectType +']-'
      $strOwnerAssignment += $stOwner
    }
  }
  return $strOwnerAssignment, $count
}

<# -----------
  Main Program
----------- #>
Write-Verbose "Starting processing..."
# Retrieve Subscriptions 
$subscriptions = Get-AzSubscription
# to have only subscriptions enabled : Get-AzSubscription | Where-Object State -eq 'Enabled'
Write-Verbose "$($subscriptions.count) subscription(s) found."
Write-Verbose "---------------------"
# Analysis of each subscription
foreach($subscription in $subscriptions)
{
  Write-Verbose "Analysis of $($subscription.Name) Subscription..."
  # if tag name declared, find matching value 
  if($TagName)
  {
    $tagValue = Get-TagOwner $subscription $TagName
    if ($tagValue -ne '-')
    {
      Write-Verbose "Tag $tagName found with value $tagValue"
    }
    else {
      Write-Verbose "Tag $tagName not found for this subscription"
    }
  }
  
  # Retrieve Owner(s) of the subscription
  $ownerAssignments, $countOwner = Get-RoleOwnerSubscription $subscription
  Write-Verbose "$countOwner Owner(s) found for this subscription"
  Write-Verbose "---------------------" 
  # Create Object for result
   if($TagName)
  {
    $objOwnerResult=@(
      [PSCustomObject]@{
        SubscriptionName = $subscription.Name
        TagName = $TagName
        TagValue = $tagValue
        Owner = $ownerAssignments
      }
    )
  }
  else {
    $objOwnerResult=@(
      [PSCustomObject]@{
        Subscription = $subscription.Name
        Owner = $ownerAssignments
      }
    )
  }
  # Add subscription result in result array
  $arraySubscriptionOwner += $objOwnerResult
}
 
# Generate the csv file
Write-Verbose "Building csv result file..."
if((CreateDirectoryResult 'GetOwnerSubscription')){
  $csvFile = '.\GetOwnerSubscription\' + (CreateChronoFile 'GetOwnerSubscription') + '.csv'
}
$arraySubscriptionOwner | Export-Csv -Path $csvFile -Delimiter ";" -NoTypeInformation
Write-Verbose "File $csvFile is available."

<# -----------
  Get-Help Informations
----------- #>

<#
  .SYNOPSIS
  This script retrieves Subscription owner(s) from Access Control (IAM) / Role Assignments and a tag if one is defined.
  
  .DESCRIPTION
  The Get-OwnerSubscription script searches owner(s) of all subscriptions from IAM and a tag if one is defined and store it 
  in the file .\GetOwnerSubscription\GetOwnerSubscriptionmmddyyyyhhmmss.csv.
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
  GetOwnerSubscriptionmmddyyyyhhmmss.csv file with results.

  .EXAMPLE
  .\Get-OwnerSubscription.ps1 : Retrieve Owner(s) in IAM.
  .\Get-OwnerSubscription.ps1 -TagName 'tag name' : Retrieve Owner(s) in both IAM and Tag Name indicated.
  .\Get-OwnerSubscription.ps1 -Verbose : Execute the script without output progress informations on console.

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>