<#
  Name    : Get-AzAhb.ps1
  Author  : Frederic Parmentier
  Version : 0.5
  Creation Date : 04/02/2024
  
  Updated date  :
  Updated by    :
  Update done   :

  Optimize OS Azure Hybrid Management
  ..\Data\GetAzAhb\GetAzAhbmmddyyyyhhmmss.csv
  For more information, type Get-Help .\Get-AzAhb.ps1 [-detailed | -full]

  Global variables are stored in .\GetAzAhb.json and must be adapted accordingly
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
$globalVar = Get-Content -Raw -Path ".\GetAzAhb.json" | ConvertFrom-Json

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
  if ((Test-Path -Path $directory) -eq $False) {
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

function ReplaceEmpty
{
  <#
    Replace an empty string by string given in parameter
    Input :
      - $checkStr : String to check
      - $replacedBy: String to set up if $checkStr is empty
    Output : 
      - $checkStr
  #>
  param(
    [String] $checkStr,
    [String] $replacedBy
  )
  if ($checkStr -match "^\s*$") { $checkStr = $replacedBy }
  return $checkStr
}

function CalcCores
{
  <#
    Retrieve for VM with Hybrid Benefit number of:
    - Cores consumed
    - Licenses consumed
    - Cores wasted
    Input:
      - $nbCores: number of cores of the VM
      - $coresByLicense: Number of cores by license
      - $licenseType: Type of License applied on VM
    Output:
      - $calcCores: array of results
  #>
  param(
    [Int16] $nbCores,
    [Int16] $coresByLicense,
    [String] $licenseType
  )

  $calcCores = @{
    coresConsumed = 0
    licensesConsumed = 0
    coresWasted = 0
  }

  $floor = [Math]::Floor($nbCores/$coresByLicense)
  $modulus = $nbCores % $coresByLicense
  # if License applied is Hybrid Benefit
  if ($licenseType -eq $globalVar.hybridBenefit.name) {
    if ($floor -eq 0 -or $nbCores -eq $coresByLicense) {
      $calcCores['coresConsumed'] = $coresByLicense
      $calcCores['licensesConsumed'] = 1
      $calcCores['coresWasted'] = $coresByLicense - $nbCores
    }
    else {
      switch ($modulus) {
        { $_ -eq 0 } {
          $calcCores['coresConsumed'] = $coresByLicense * $floor
          $calcCores['licensesConsumed'] = $floor
          $calcCores['coresWasted'] = 0
        }
        { $_ -gt 0 } {
          $calcCores['coresConsumed'] = ($coresByLicense * $floor) + $coresByLicense
          $calcCores['licensesConsumed'] = $floor + 1
          $calcCores['coresWasted'] = ($coresByLicense * ($floor + 1)) - $nbCores
        }
      }
    }
  }
  return $calcCores
}

function GetVmInfo
{
  <#
    Retrieve for VM:
    OsType, LicenseType, SKU, Environment and Availibity,
    filter by OsType = Windows
    Input:
      - $rgName: Resource Group Name
      - $vmName: Virtual Machine Name
    Output:
      - $resInfos: array of results
  #>
  param(
    [String] $rgName,
    [String] $vmName
  )
  $resInfos = @()
  try {
    $resInfos = (Get-AzVM -ResourceGroupName $rgName -Name $vmName |
      Where-Object { $_.StorageProfile.OSDisk.OsType -eq $($globalVar.osTypeFilter) } |
      ForEach-Object {
        $_.StorageProfile.OSDisk.OsType, $_.LicenseType, $_.HardwareProfile.VmSize,
        $_.tags.$($globalVar.tags.environment), $_.tags.$($globalVar.tags.availability)
      }
    )
    if ($resInfos.count -ne 0) {
      # If Tags are empty, replaced by "-"
      $resInfos[3] = (ReplaceEmpty -checkStr $resInfos[3] -replacedBy "-")
      $resInfos[4] = (ReplaceEmpty -checkStr $resInfos[4] -replacedBy "-")
      # search if Hybrid benefit or Virtual desktop license and replace name in $resInfos
      switch ($resInfos[1].ToUpper()) {
        $globalVar.hybridBenefit.licenseType.ToUpper() { $resInfos[1] = $globalVar.hybridBenefit.name }
        $globalVar.virtualDesktop.licenseType.ToUpper() { $resInfos[1] = $globalVar.virtualDesktop.name}
      }
    }
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    $resInfos = @("Error", "Error", "Error", "Error", "Error")
  }
  return $resInfos
}

function GetVmSizing
{
  <#
    Retrieve for VM: Number of Cores and RAM in MB
    Input:
      - $rgName: Resource Group Name
      - $vmName: Virtual Machine Name
      - $sku: SKU of Virtual Machine
    Output:
      - $resSizing: array of results
  #>
  param(
    [String] $rgName,
    [String] $vmName,
    [String] $sku
  )
  $resSizing = @()
  try {
    $resSizing = (Get-AzVMSize -ResourceGroupName $rgName -VMName $vmName |
      Where-Object { $_.Name -eq $($sku) } |
      Select-Object -Property NumberOfCores, MemoryInMB
    )
  }
  catch {
    Write-Host "An error occured retrieving VM informations for $vmName"
    $resSizing = @("Error", "Error")
  }
  return $resSizing
}

function SetObjResult {
  <#
    $listResult must contains 9 elements
  #>
  param(
    [array] $listResult
  )
  if ($listResult.Count -ne 17) {
    $listResult = @('-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '-',"-","-")
  }
  $objTagResult = @(
    [PSCustomObject]@{
      Subscription = $listResult[0]
      SubscriptionId = $listResult[1]
      ResourceGroup = $listResult[2]
      Vm_Name = $listResult[3]
      Location = $listResult[4]
      PowerState = $listResult[5]
      Os_Type = $listResult[6]
      Os_Name = $listResult[7]
      License_Type = $listResult[8]
      Size = $listResult[9]
      Nb_Cores = $listResult[10]
      Ram = $listResult[11]
      tag_Environment = $listResult[12]
      tag_Availability = $listResult[13]
      Nb_Cores_Consumed = $listResult[14]
      Nb_Licenses_Consumed = $listResult[15]
      Nb_Cores_Wasted = $listResult[16]
    }
  )
  return $objTagResult
}
#
<# -----------
  Main Program
----------- #>
# Create directory results if not exists and filename for results
# if chronoFile is set to "Y", Create a chrono to the file with format MMddyyyyHHmmss
if ((CreateDirectoryResult $globalVar.pathResult)) {
  if ($globalVar.chronoFile.ToUpper() -eq "Y") {
    $csvFile = $globalVar.pathResult + (CreateChronoFile $globalVar.fileResult) + '.csv'
  }
  else {
    $csvFile = $globalVar.pathResult + $globalVar.fileResult + '.csv'
  }
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
if ($subscriptions.Count -ne 0) {
  foreach ($subscription in $subscriptions) {
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
    if ($resourceGroupNames.Count -ne 0) {
      foreach ($resourceGroupName in $resourceGroupNames) {
        $objVmResult = @()
        $arrayVm = @()
        #
        <# ------------
          VM processing
        ------------ #>
        Write-Verbose "--- Processing of VMs from Resource Group $($resourceGroupName.ResourceGroupName)"
        $vms = (
          Get-AzVM -ResourceGroupName $resourceGroupName.ResourceGroupName -Status |
          Select-Object -Property Name, Location, OsName, PowerState
        )
        Write-Verbose "--- $($vms.Count) VMs found"
        #
        # if there are Virtual Machines
        if ($vms.Count -ne 0) {
          foreach ($vm in $vms) {
            # -- Retrieve VM informations
            $vmInfos = GetVmInfo -rgName $resourceGroupName.ResourceGroupName -vmName $vm.Name
            # if there VM matching with $osTypeFilter
            if ($vmInfos.Count -ne 0) {
              # -- Retrieve VM sizing
              $vmSizing = GetVmSizing -rgName $resourceGroupName.ResourceGroupName -vmName $vm.Name -sku $vmInfos[2]
              $resultCores = CalcCores -nbCores $vmSizing.NumberOfCores -coresByLicense $globalVar.weightLicenseInCores -licenseType $vmInfos[1]
              # Aggregate informations
              $objVmResult += SetObjResult @(
                $subscription.Name, $subscription.Id, $resourceGroupName.ResourceGroupName,
                $vm.Name, $vm.Location, $vm.PowerState,
                $vmInfos[0], $vm.OsName, $vmInfos[1],
                $vmInfos[2], $vmSizing.NumberOfCores, $vmSizing.MemoryInMB,
                $vmInfos[3],$vmInfos[4],$resultCores['CoresConsumed'], $resultCores['licensesConsumed'], $resultCores['coresWasted']
              )
            }
          }
        }
        # Write in results in result file
        $arrayVm += $objVmResult
        $arrayVm | Export-Csv -Path $csvFile -Delimiter ";" -NoTypeInformation -Append
      }
    }
    Write-Verbose "---------------------------------------------"
  }
}

Write-Verbose "File $csvFile is available."

# --------------- POUR TEST ------
Get-Date
# --------------- POUR TEST ------

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
