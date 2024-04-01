<#
  Name    : Get-VMStatus.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 03/06/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Retrieve VM Status in subscriptions, and store them in 
  .\GetVMStatus\GetVMStatusmmddyyyyhhmmss.csv
  For more information, type Get-Help .\Get-VMStatus.ps1 [-detailed | -full]
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

function SetObjResult {
  <#
    $listResult must contains 9 elements
  #>
  param(
    [array] $listResult
  )
  if($listResult.Count -ne 9){
    $listResult=@('-', '-', '-', '-', '-', '-', '-', '-', '-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      SubscriptionName = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroupName = $listResult[2]
      ResourceGroupId = $listResult[3]
      VmName = $listResult[4]
      Location = $listResult[5]
      VmSize = $listResult[6]
      OsType = $listResult[7]
      PowerState = $listResult[8]
    }
  )
  return $objTagResult
}

<# -----------
  Main Program
----------- #>
# Create file name
if((CreateDirectoryResult 'GetVMStatus')){
  $csvFile = '.\GetVMStatus\' + (CreateChronoFile 'GetVMstatus') + '.csv'
}
Write-Verbose "Starting processing..."
# retrieve Subscriptions enabled
# $subscriptions = Get-AzSubscription | Where-Object -Property State -eq "Enabled"
$subscriptions = Get-AzSubscription | Where-Object {($_.Name -clike "*DXC*") -and ($_.State -eq "Enabled")}

Write-Verbose "$($subscriptions.Count) subscriptions found."
if($subscriptions.Count -gt 0){
  foreach($subscription in $subscriptions){
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    Set-AzContext -Subscription $subscription
    <# ------------
      ResourceGroup processing
    ------------ #>
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroupNames = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName, ResourceId | Sort-Object ResouceGroupName)
    Write-Verbose "-- $($resourceGroupNames.Count) Resource Groups found"
    if($resourceGroupNames.Count -gt 0){
      foreach($resourceGroupName in $resourceGroupNames){
        $objVmResult = @()
        $arrayVm = @()
        <# ------------
          VM processing
        ------------ #>
        Write-Verbose "--- Processing of VMs from Resource Group $($resourceGroupName.ResourceGroupName)"
        $vms = (Get-AzVM -ResourceGroupName $resourceGroupName.ResourceGroupName -Status | Select-Object -Property Name, Location, OsName, PowerState -ExpandProperty HardwareProfile | Sort-Object Location, Name)
        Write-Verbose "--- $($vms.Count) VMs found"
        if($vms.Count -gt 0){
          foreach($vm in $vms){
            $objVmResult += SetObjResult @($subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName, $resourceGroupName.ResourceId, $vm.Name, $vm.Location, $vm.VmSize, $vm.OsName, $vm.PowerState)
          }
        }
        $arrayVm += $objVmResult
        $arrayVm | Export-Csv -Path $csvFile -Delimiter ";" -NoTypeInformation -Append
      }
    }
    Write-Verbose "---------------------------------------------"
  }
}

Write-Verbose "File $csvFile is available."

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
