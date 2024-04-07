####################################
# FINOPS - Azure Zombie query tool #
# v1.0     -   27/11/2023          #
# CAPGEMINI FRANCE PROPERTY        #
# Cedric GEORGEOT                  #
####################################

# Modules importation
$modules = 'Az.Accounts','Az.Compute','Az.ResourceGraph','ImportExcel' # PS Module required
import-module $modules

# Suppress breaking changes
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true" 

# Name of the analyze
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$title = '** SUEZ ** FinOps Zombie query tool'
$msg   = 'Please enter the name of the analyze:'
$costname = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

# Creation of the directroy
New-Item -Path "c:\Azurecost\zombie\$costname" -ItemType "directory" -force
set-location c:\azurecost\zombie\$costname

# FinOps queries using Azure graph
$resultA = Search-AzGraph -query "resources | 
  where type =~ 'microsoft.compute/disks' | 
  where properties.diskState =~ 'Unattached' | 
  extend optimization = 'Disks_unattached' | 
  project optimization, name, id, subscriptionId, resourceGroup, location"  -first 1000 
$resultA | Export-Csv -Path c:\Azurecost\zombie\$costname\A-disk.csv -NoTypeInformation 

$resultB = Search-AzGraph -query "resources | 
  where type =~ 'microsoft.web/serverfarms' | 
  where properties.numberOfSites == 0 | 
  extend Details = pack_all() | 
  extend optimization = 'App_service' | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -first 1000 
$resultB | Export-Csv -Path c:\Azurecost\zombie\$costname\B-AppServ.csv -NoTypeInformation 

$resultC = Search-AzGraph -query "Resources | 
  where type == 'microsoft.network/publicipaddresses' | 
  extend optimization = 'Public_IP' | 
  where properties.ipConfiguration == '' and properties.natGateway == '' and properties.publicIPPrefix == '' | 
  extend Details = pack_all() | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -first 1000
$resultC | Export-Csv -Path c:\Azurecost\zombie\$costname\C-IP.csv -NoTypeInformation 

$resultD = Search-AzGraph -query "Resources | where type has 'microsoft.network/networkinterfaces' | 
  where isnull(properties.privateEndpoint) | 
  extend optimization = 'NIC'| 
  where isnull(properties.privateLinkService) | 
  where properties.hostedWorkloads == '[]' | 
  where properties !has 'virtualmachine' | 
  extend Details = pack_all() | 
  extend AllProperties = todynamic(tags) | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -First 1000
$resultD | Export-Csv -Path c:\Azurecost\zombie\$costname\D-NIC.csv -NoTypeInformation 

$resultE = Search-AzGraph -query "ResourceContainers | 
  where type == 'microsoft.resources/subscriptions/resourcegroups'  | 
  extend optimization = 'RG_empty' |
  extend rgAndSub = strcat(resourceGroup, '--', subscriptionId)  | join kind=leftouter (Resources  | 
  extend rgAndSub = strcat(resourceGroup, '--', subscriptionId)      | 
  summarize count() by rgAndSub  ) on rgAndSub  | where isnull(count_)  | 
  extend Details = pack_all()  | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -first 1000
$resultE | Export-Csv -Path c:\Azurecost\zombie\$costname\E-RG.csv -NoTypeInformation 

$resultF = Search-AzGraph -query "Resources | 
  where type == 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets) | 
  extend optimization = 'NSG' |extend Details = pack_all() | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -first 1000
$resultF | Export-Csv -Path c:\Azurecost\zombie\$costname\F-NSG.csv -NoTypeInformation 

$resultG = Search-AzGraph -query "resources | 
  where type == 'microsoft.network/routetables' | 
  extend optimization = 'Route_tables' | 
  where isnull(properties.subnets) | 
  extend Details = pack_all() | 
  project optimization, name, id, subscriptionId, resourceGroup, location" -first 1000
$resultG | Export-Csv -Path c:\Azurecost\zombie\$costname\G-RT.csv -NoTypeInformation 

$resultH = Search-AzGraph -query "advisorresources  | 
  where type == 'microsoft.advisor/recommendations' | 
  where properties.category == 'Cost' | 
  extend optimization = 'VM' | 
  where properties.shortDescription.solution contains 'Right-size'  | 
  where properties.extendedProperties.recommendationType =='Shutdown' | 
  project optimization, name=properties.extendedProperties.roleName, id, subscriptionId, resourceGroup, location=properties.extendedProperties.regionId,'','','','','','','','' " -first 1000
$resultH | Export-Csv -Path c:\Azurecost\zombie\$costname\H-VM.csv -NoTypeInformation 

#Suppression des 1eres lignes des CSV
$cheminRepertoire = "C:\Azurecost\zombie\$costname"
$listeFichiers = Get-ChildItem -Path $cheminRepertoire -Filter *.csv

foreach ($fichier in $listeFichiers) {
    # Ignorer les répertoires
    if ($fichier.PSIsContainer) {
        continue
    }

    # Lire le contenu du fichier, exclure la première ligne, puis sauvegarder
    $contenuFichier = Get-Content $fichier.FullName | Select-Object -Skip 1
    $contenuFichier | Set-Content $fichier.FullName -Force
}

Write-Host "Suppression de la première ligne terminée pour tous les fichiers dans le répertoire."

$cheminFichierSortie = "C:\Azurecost\zombie\$costname\Inventory.csv"

$listeFichiers = Get-ChildItem -Path $cheminRepertoire -Filter *.csv

# Parcourir chaque fichier CSV et concaténer les contenus
foreach ($fichier in $listeFichiers) {
    # Ignorer les répertoires
    if ($fichier.PSIsContainer) {
        continue
    }

    # Lire le contenu du fichier CSV et l'ajouter au fichier de sortie
    Get-Content $fichier.FullName | Add-Content -Path $cheminFichierSortie
}

Write-Host "Concaténation des fichiers CSV terminée. Les données ont été enregistrées dans $cheminFichierSortie."

$premiereLigne = "optimization,name,id,subscriptionId,resourceGroup,location,owner_contact,operational_contact,owner_dl,financial_contact,app_id,billing_code,app_family,ResourceId"
$contenuExistant = Get-Content $cheminFichierSortie
$contenuFinal = @($premiereLigne) + $contenuExistant
$contenuFinal | Set-Content $cheminFichierSortie



#Write-Host "La première ligne a été ajoutée avec succès au fichier CSV."
Rename-Item "C:\Azurecost\zombie\$costname\Inventory.csv" "C:\Azurecost\zombie\$costname\Inventory.temp"
remove-item "c:\azurecost\zombie\$costname\*.csv" -force
Rename-Item "C:\Azurecost\zombie\$costname\Inventory.temp" "C:\Azurecost\zombie\$costname\A-Inventory.csv"

$resultA1 = Search-AzGraph -query "resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, name" -first 1000 
$resultA1 | Export-Csv -Path c:\Azurecost\zombie\$costname\B-Mapping.csv -NoTypeInformation 

$resultR = search-azgraph -query "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups' | project name, id, subscriptionId, resourceGroup, location, owner_contact=tags.owner_contact, operational_contact=tags.operational_contact, owner_dl=tags.owner_dl, financial_contact=tags.financial_contact, app_id=tags.app_id, billing_code=tags.billing_code, app_family=tags.app_family" -Subscription $sub -first 1000 
$resultR | Export-Csv -Path c:\azurecost\zombie\$costname\C-RGtags.csv -NoTypeInformation 

# Merging csv files into Excel sheet
Install-Module ImportExcel -scope CurrentUser -force
$csvs = Get-ChildItem c:\azurecost\zombie\$costname\* -Include *.csv
$csvCount = $csvs.Count
Write-Host "Detection des fichiers CSV suivants: ($csvCount)"
    foreach ($csv in $csvs) {
        Write-Host " -"$csv.Name
    }
    
    $excelFileName = $(get-date -f ddMMyyyy) + "_" + $env:USERNAME + "_SUEZ_" +$costname + ".xlsx"
    Write-Host "Creation du fichier: $excelFileName"
        
    foreach ($csv in $csvs) {
            $csvPath = "c:\azurecost\zombie\$costname\" + $csv.Name
            $worksheetName = $csv.Name.Replace(".csv","")
            Write-Host " - Ajout du CSV $worksheetName dans le fichier $excelFileName"
            Import-Csv -Path $csvPath | Export-Excel -Path $excelFileName -WorkSheetname $worksheetName
        }


#nettoyage final
remove-item c:\azurecost\zombie\$costname\*.csv -force