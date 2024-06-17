<#
  Name    : Get-AzInstanceRi.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 06/06/2024
                   
  Add in file Instances[mmddyyyyhhmmss].csv the VM size (Product name) contained in the 

  ========  A REVOIR ================

  Global variables are stored in .\Get-AzVmUsageRi.json and must be adapted accordingly
#>

<# -----------
  Declare input parameters
----------- #>
[cmdletBinding()]

param(
  [Parameter(Mandatory = $true)]
  [String]$TargetFile
)

# --- Disable breaking change Warning messages in Azure Powershell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

<# -----------
  Declare global variables, arrays and objects
----------- #>
# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path "$($PSScriptRoot)\Get-AzVmUsageRi.json" | ConvertFrom-Json
#
# $targetFile = "C:/Users/fparment/Documents/AzFinOps/Data/ReservedInstances/Instances.csv"
$instances = @()

$listInstances = Import-Csv -Path $globalVar.reservedInstance.sourceFile -Delimiter "," | Where-Object -Property type -eq  $($globalVar.reservedInstance.type) |
Select-Object -Property 'Product name'

foreach ($instance in $listInstances) {
  $instances += @(
      [PSCustomObject]@{
        Instance = $instance.'Product name'
      }
    )
}
$instances | Export-Csv -Path $TargetFile -Delimiter ";" -NoTypeInformation -Append
