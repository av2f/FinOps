###################################
# FINOPS - Azure graph query tool #
# v2.1BETA - SUEZ IT   29/10      #
###################################

# Modules importation
# $modules = 'Az.Accounts','Az.Compute','Az.ResourceGraph','ImportExcel' # PS Module required
# import-module $modules

# IF specific RG to analyse
# $RG = "'RG1','RG2'"
# $queryrg = "where resourceGroup in~ ($RG)"
# In azgraph query put: | $queryrg | between two queries

# Suppress breaking changes
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true" 

# Connect to Azure
#Connect-AzAccount

# Name of the analyze
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$title = '** SUEZ ** FinOps query tool'
$msg   = 'Please enter the name of the analyze:'
$costname = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

# Subscription(s) selection - CTRL & click to select more than 1 subscription
$subquery = (Get-AzSubscription | Out-GridView -Title "Select an Azure Subscription" -PassThru)
$sub = $subquery.Id
Write-Host "Subscription(s) selected: $sub.Id" -ForegroundColor Green  

# Creation of the directroy
New-Item -Path "c:\" -Name "Azurecost\$costname" -ItemType "directory" -force
set-location c:\azurecost\$costname

# FinOps queries using Azure graph
$resultA = Search-AzGraph -query "resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, name" -Subscription $sub -first 1000 
$resultA | Export-Csv -Path c:\Azurecost\$costname\A-mapping.csv -NoTypeInformation 

$resultB = search-azgraph -query "resources | where type startswith 'microsoft.sql' |extend AllProperties = todynamic(tags) | project name, Owner = AllProperties ['owner'], Availability =AllProperties['availability'], Application = AllProperties['application'], Environment = AllProperties['environment'], type, sku.name, sku.tier, sku.capacity, kind, properties.currentServiceObjectiveName, properties.licenseType, properties.sqlImageOffer, properties.sqlImageSku, properties.sqlServerLicenseType, location, resourceGroup, subscriptionId" -Subscription $sub -first 1000 
$resultB | Export-Csv -Path c:\azurecost\$costname\B-sqlHB.csv -NoTypeInformation

$resultC = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | extend AllProperties = todynamic(tags) | project name, Owner = AllProperties ['owner'], Availability =AllProperties['availability'], Application = AllProperties['application'], Environment = AllProperties['environment'], location, subscriptionId, resourceGroup, properties.hardwareProfile.vmSize, properties.storageProfile.osDisk.osType,properties.storageProfile.imageReference.offer,properties.storageProfile.imageReference.sku,properties.licenseType, properties.host.id,properties.extended.instanceView.powerState.displayStatus" -Subscription $sub -first 1000 
$resultC | Export-Csv -Path c:\azurecost\$costname\C-vmHB.csv -NoTypeInformation 

$resultD = Search-AzGraph -Query "Resources | where type == 'microsoft.compute/virtualmachinescalesets' | extend AllProperties = todynamic(tags) | project name, Owner = AllProperties ['owner'], Availability =AllProperties['availability'], Application = AllProperties['application'], Environment = AllProperties['environment'], resourceGroup, subscriptionId, sku.name, sku.capacity, properties.storageProfile.osDisk.osType,  properties.virtualMachineProfile.storageProfile.imageReference.offer, properties.virtualMachineProfile.storageProfile.imageReference.sku,properties.virtualMachineProfile.licenseType, properties.hostGroup.id" -Subscription $sub -first 1000 
$resultD | Export-Csv -Path c:\azurecost\$costname\L-containers.csv -NoTypeInformation 

$resultE = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | extend AllProperties = todynamic(tags) | project name, Owner = AllProperties ['owner'], Availability =AllProperties['availability'], Application = AllProperties['application'], STARTSTOP = AllProperties['startmwtf'], Environment = AllProperties['environment'], location, resourceGroup, subscriptionId, properties.hardwareProfile.vmSize, properties.extended.instanceView.powerState.displayStatus, properties.storageProfile.osDisk.osType, properties.storageProfile.imageReference.publisher" -Subscription $sub -first 1000 
$resultE | Export-Csv -Path c:\azurecost\$costname\K-vmwithTAGS.csv -NoTypeInformation 

$resultF = Search-AzGraph -Query "Resources | where type =~ 'microsoft.compute/disks'  | where properties.diskState =~ 'Unattached' | project name, properties.diskState, subscriptionId, resourceGroup, sku.name, sku.tier, properties.diskSizeGB" -Subscription $sub -first 1000 
$resultF| Export-Csv -Path c:\azurecost\$costname\J-disksunattached.csv -NoTypeInformation 

$resultG = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines'  | extend AllProperties = todynamic(properties.extended.instanceView.powerState)  | where AllProperties.code =~ 'PowerState/deallocated'  | extend AllPropertie = todynamic(tags) | project name, Owner = AllPropertie['owner'], Availability =AllPropertie['availability'], Application = AllPropertie['application'], Environment = AllPropertie['environment'], AllProperties.code, subscriptionId, resourceGroup" -Subscription $sub -first 1000 
$resultG | Export-Csv -Path c:\azurecost\$costname\I-stoppedVM.csv -NoTypeInformation 

$resultH = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains  'MySQL' | project properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultH | Export-Csv -Path c:\azurecost\$costname\D-mysqlcapacity.csv -NoTypeInformation 

$resultI = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'DB' | project properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultI | Export-Csv -Path c:\azurecost\$costname\E-sqlcapacity.csv -NoTypeInformation

$resultJ = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'Postgre' | project properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultJ | Export-Csv -Path c:\azurecost\$costname\F-postgrecapacity.csv -NoTypeInformation 

$resultK = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'Right-size' | project properties.extendedProperties.roleName, properties.extendedProperties.currentSku , properties.extendedProperties.targetSku, properties.extendedProperties.MaxMemoryP95, properties.extendedProperties.MaxCpuP95, resourceGroup, subscriptionId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultK | Export-Csv -Path c:\azurecost\$costname\H-rightsize.csv -NoTypeInformation 

$resultL = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains  'virtual machine reserved' | project properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.reservationType, properties.extendedProperties.vmSize, subscriptionId, properties.resourceMetadata.resourceId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultL | Export-Csv -Path c:\azurecost\$costname\G-AzureRI.csv -NoTypeInformation 

$resultM = search-azgraph -query "resources | where type =~ 'microsoft.compute/disks' | where properties.diskState =~ 'reserved' | project name, properties.diskState, properties.diskSizeGB, location, resourceGroup, subscriptionId, sku.name, sku.tier" -Subscription $sub -first 1000 
$resultM | Export-Csv -Path c:\azurecost\$costname\M-Reserveddisk.csv -NoTypeInformation 

$resultM = search-azgraph -query "Resources | summarize count() by type, location, resourceGroup, subscriptionId" -Subscription $sub -first 1000 
$resultM | Export-Csv -Path c:\azurecost\$costname\N-ResourcesCount.csv -NoTypeInformation 

$resultN = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'Maria' | project properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultN | Export-Csv -Path c:\azurecost\$costname\O-MariaDB.csv -NoTypeInformation 

$resultO = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'Cosmo'| project resourceGroup, properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultO | Export-Csv -Path c:\azurecost\$costname\P-Cosmo.csv -NoTypeInformation 

$resultP = search-azgraph -query "advisorresources | where type == 'microsoft.advisor/recommendations' | where properties.category == 'Cost' | where properties.shortDescription.solution contains 'App Service' | project resourceGroup, properties.extendedProperties.annualSavingsAmount, properties.extendedProperties.displayQty, properties.extendedProperties.displaySKU, properties.extendedProperties.subId, properties.shortDescription.solution" -Subscription $sub -first 1000 
$resultP | Export-Csv -Path c:\azurecost\$costname\Q-Appsrv.csv -NoTypeInformation 
    
# Get VM Size with RAM & CPU     
$result = Get-AZVMSize -Location "westeurope" 
$result | Export-Csv -Path c:\azurecost\$costname\Z-cores.csv -NoTypeInformation

# Merging csv files into Excel sheet
Install-Module ImportExcel -scope CurrentUser
$csvs = Get-ChildItem c:\azurecost\$costname\* -Include *.csv
$csvCount = $csvs.Count
Write-Host "Detection des fichiers CSV suivants: ($csvCount)"
    foreach ($csv in $csvs) {
        Write-Host " -"$csv.Name
    }
    
$excelFileName = $(get-date -f ddMMyyyy) + "_" + $env:USERNAME + "_SUEZ_" +$costname + ".xlsx"
Write-Host "Creation du fichier: $excelFileName"
    
foreach ($csv in $csvs) {
        $csvPath = "c:\azurecost\$costname\" + $csv.Name
        $worksheetName = $csv.Name.Replace(".csv","")
        Write-Host " - Ajout du CSV $worksheetName dans le fichier $excelFileName"
        Import-Csv -Path $csvPath | Export-Excel -Path $excelFileName -WorkSheetname $worksheetName
    }

# Delete csv files    
remove-item c:\azurecost\$costname\*.csv -force

##############
#END OF SCRIPT
##############