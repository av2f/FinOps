<#
Test sur un tag Virtual machine
Subscription Name: EA DXC Cloud Ops managed services for Alstom Prod
Subscription ID: c5ea61f3-1975-4b59-9e9c-66128b8989f3
ResourceGroup: sdc7-05207-prod-rg
Resource (VM): srsdc705207l001
ResourceId : /subscriptions/c5ea61f3-1975-4b59-9e9c-66128b8989f3/resourceGroups/sdc7-05207-prod-rg/providers/Microsoft.Compute/virtualMachines/srsdc705207l001
Tags:
AIPCode	5207
AIPDescription	EAI allowing exanges between various systems (ERP SAP, MES, ASCOT, ...)
dxcMonitored	True
dxcManaged	Partial
Customer	Alstom Transport
DepartmentName	SAP Competence Center
dxcAutoShutdownSchedule	Disabled;00:00 -> 00:00
dxcEPAgent	CarbonBlack
Owner	Alexandre.schmitt@alstomgroup.com;sumodh.p@alstomgroup.com
PatchingSchedule	Phase 3 - Quarterly
ServiceWindows	24x7-CET (00:00-24:00 Mon-Sun)
SLA	AzureManaged
Supported	CloudOps
TempPatchingExclusion	Yes
dxcBackup	False
dxcAlstComplianceCheck	dxcMonitored:True;dxcBackup:NotProtected;dxcEPAgent:Registered
dxcAlstAutoProvisioned	False
AIPCriticality	Business critical
AIPOwner	sumodh.p@alstomgroup.com
dxcAlstTaggingLock	False
dxcConfigurationCheck	20240410T105232Z
PRJNumber	
GoLiveDate	
IsItemizable	False
AIPName	TRT SAP PI
SpecialHandling	
Environment	Prod
Location	SDC7
Region	North Europe
ResourceType	VM
#>


# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path ".\SearchString.json" | ConvertFrom-Json

# set to the right context
Set-AzContext -Subscription "c5ea61f3-1975-4b59-9e9c-66128b8989f3"

# Retrieve Tags
$resourceGroupName = "sdc7-05207-prod-rg"
$resource = (Get-AzResource -ResourceGroupName $resourceGroupName | Where-Object Name -eq 'srsdc705207l001' | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags)

$patterns = $globalVar.finopsTags.patterns.split(",")
Write-Host $patterns.count

if ($resource.Tags.Count -ne 0) {
  foreach ($key in $resource.Tags.keys) {
    foreach ($pattern in $patterns) {
      if ($key -match $pattern) {
        Write-Host "$key Match with $pattern"
      }
    }
  }
}
<#
Write-Host $a.gettype()
Write-Host $a
Write-Host $a.count

$c=@("AIPCode", "DepartmentName")

$d = @()
foreach ($b in $a) {
  if ($c -match "cod") {
    Write-Host "Good"
    $d += $c
  }
  else {
    Write-Host "Revoie ta copie"
  }
}
Write-Host $d
#>