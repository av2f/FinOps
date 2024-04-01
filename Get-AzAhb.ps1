<#
  Name    : Get-AzAhb.ps1
  Author  : Frederic Parmentier
  Version : 0.1
  Creation Date : 04/01/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Optimize OS Azure Hybrid Management
  ..\Data\GetAzAhb\GetAzAhbmmddyyyyhhmmss.csv
  For more information, type Get-Help .\Get-AzAhb.ps1 [-detailed | -full]
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
# Directory where is stored results. Change if needed
$directoryAndFileResult = "GetAzAhb"
$dataDirectoryResult = "D:\azFinOps\Data\" + $directoryAndFileResult
# Map tags for environment and availability. Change if needed
$tags=@{}
$tags.Add('environment', 'Environment')
$tags.Add('availability', 'ServiceWindows')
# Filter on OSType = 'Windows'
$osTypeFilter = 'Windows'

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
  Write-Verbose "la directory est $directory"
  if((Test-Path -Path $directory) -eq $False){
    New-Item -Path $directory -ItemType "directory"
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
  if($listResult.Count -ne 14){
    $listResult=@('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-')
  }
  $objTagResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroup = $listResult[2]
      VmName = $listResult[3]
      Location = $listResult[4]
      PowerState = $listResult[5]
      OsType = $listResult[6]
      OsName = $listResult[7]
      LicenseType = $listResult[8]
      Size = $listResult[9]
      NbCores = $listResult[10]
      Ram = $listResult[11]
      tagEnvironment = $listResult[12]
      tagAvailability = $listResult[13]
    }
  )
  return $objTagResult
}

<# -----------
  Main Program
----------- #>
# Create file name
if((CreateDirectoryResult $dataDirectoryResult)){
  $csvFile = $dataDirectoryResult + '\' + (CreateChronoFile $directoryAndFileResult) + '.csv'
}
Write-Verbose "Starting processing..."
# ---- For Tests, use 1 subscription ----
# retrieve Subscriptions enabled
# $subscriptions = Get-AzSubscription | Where-Object -Property State -eq "Enabled"
# $subscriptions = Get-AzSubscription | Where-Object {($_.Name -clike "*DXC*") -and ($_.State -eq "Enabled")}
$subscriptions = @(
  [PSCustomObject]@{
    Name = 'EA DXC Cloud Ops managed services for Alstom Prod'
    Id = 'c5ea61f3-1975-4b59-9e9c-66128b8989f3'
  },
  [PSCustomObject]@{
    Name = 'EA DXC Cloud Ops managed services for Alstom'
    Id = 'a6e9693b-e3d6-4e21-a5ce-e32d948941f9'
  },
  [PSCustomObject]@{
    Name = 'EA DXC Cloud Ops managed services for Alstom Non-Prod'
    Id = '80f0f1bc-6d6f-4d58-a6ea-6a1aefb4bb21'
  },
  [PSCustomObject]@{
    Name = 'EA C&C Reserved Instances'
    Id = '9b371cae-5572-48a9-a529-9972ae6a56cb'
  },
  [PSCustomObject]@{
    Name = 'EA DXC Cloud Ops managed services for Alstom VDE'
    Id = '82890a99-40b6-4702-9f65-7ef66eb4e908'
  },
  [PSCustomObject]@{
    Name = 'EA C&C managed services for Alstom Prod'
    Id = 'd07ad70b-b32c-4090-a052-3023ecfdfa11'
  }
)

<# --- For tests on 1 resourcegroup 
$resourceGroupNames = @(
  [PSCustomObject]@{
    ResourceGroupName = 'sdc3-08733-preprod-rg'
  }
) #>

Write-Verbose "$($subscriptions.Count) subscriptions found."
if($subscriptions.Count -gt 0){
  foreach($subscription in $subscriptions){
    <# ------------
      Subscription processing
    ------------ #>
    # Set the context to use the specified subscription
    Write-Verbose "- Processing of the $($subscription.Name) subscription."
    
    # ===== En commentaire pour tests =======
    # Set-AzContext -Subscription $subscription
    # ================
    
    Set-AzContext -Subscription $subscription.Id
    
    <# ------------
      ResourceGroup processing
    ------------ #>
    Write-Verbose "-- Processing of Resource Groups from $($subscription.Name)"
    $resourceGroupNames = (Get-AzResourceGroup | Select-Object -Property ResourceGroupName | Sort-Object ResouceGroupName)
    Write-Verbose "-- $($resourceGroupNames.Count) Resource Groups found"
    if($resourceGroupNames.Count -gt 0){
      foreach($resourceGroupName in $resourceGroupNames){
        $objVmResult = @()
        $arrayVm = @()
        
        <# ------------
          VM processing
        ------------ #>
        Write-Verbose "--- Processing of VMs from Resource Group $($resourceGroupName.ResourceGroupName)"
        $vms = (
          Get-AzVM -ResourceGroupName $resourceGroupName.ResourceGroupName -Status |
          Select-Object -Property Name, Location, OsName, PowerState
        )
        Write-Verbose "--- $($vms.Count) VMs found"
        if($vms.Count -gt 0){
          foreach($vm in $vms){
            # -- Retrieve VM informations
            $vmInfo = (
              Get-AzVM -ResourceGroupName $resourceGroupName.ResourceGroupName -Name $vm.Name |
              Where-Object { $_.StorageProfile.OSDisk.OsType -eq $($osTypeFilter) } |
              ForEach-Object {
                $_.StorageProfile.OSDisk.OsType, $_.LicenseType, $_.HardwareProfile.VmSize,
                $_.tags.$($tags['environment']), $_.tags.$($tags['availability'])
              }
            )
            # if the VM is matching with $osTypeFilter
            if($vmInfo.Count -gt 0) {
              # Check if Tags are empty, replaced by "-"
              if($vmInfo[3] -match "^\s*$") { $vmInfo[3] = "-"}
              if($vmInfo[4] -match "^\s*$") { $vmInfo[4] = "-"}
              #
              # -- Retrieve VM sizing
              $vmSizing = (
                Get-AzVMSize -ResourceGroupName $resourceGroupName.ResourceGroupName -VMName $vm.Name |
                Where-Object { $_.Name -eq $($vmInfo[2]) } |
                Select-Object -Property NumberOfCores, MemoryInMB
              )
              $objVmResult += SetObjResult @(
                $subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName,
                $vm.Name, $vm.Location, $vm.PowerState,
                $vmInfo[0], $vm.OsName, $vmInfo[1],
                $vmInfo[2], $vmSizing.NumberOfCores, $vmSizing.MemoryInMB,
                $vmInfo[3],$vmInfo[4]
              )
            }
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
