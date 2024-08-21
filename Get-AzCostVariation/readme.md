Name    : Get-AzCostVariation.ps1
Version : 1.0

** Description **
Calculates the cost variation and the variation in percent between M-1 and M resources costs

Global variables are stored in .\Get-AzCostVariation.json and must be adapted accordingly

** Created by **
Author: Frederic Parmentier
Date: 08-20-2024

** Usage **
Prerequisites:
- Ensure you retrieves resources costs csv files from M-1 and M 

- Ensure to set up correctly the Json parameter file

- Running the script : type the command ".\Get-AzCostVariation.ps1

** JSON parameter file **
the file Get-AzCostVariation.json must be configured : 
  "workPath": Path where are resources costs csv files from M-1 and M and where is the csv result file
  Example: "C:/Documents/AzFinOps/Data/GetAzCostVariation/",
  
  "filePreviousMonth": Name of the csv file from previous Month (M-1)
  Exemple: "CostManagement_M-1.csv",
  
  "fileCurrentMonth": Name of the csv file from current Month (M)
  Example: "CostManagement_M.csv",
  
  "fileResult": name of the csv file result
  Example: "Get-AzCostVariation",
  
  "chronoFile": "Y"|"N". If "Y", add a chrono to the result file with format "MMddyyyyHHmmss"
  
  "generateLogFile": "Y"|"N". If "Y", Generates a log file
  
  "type": "All" | list of resources
  if "All", calculates for all resources
  if list of resources, calculates only for resources specified
  example of list: "Virtual machine,Disk, Storage account"

** Result file **
the result file is in csv format with following columns:
SubscriptionName: Subscription where the resource is
ResourceGroupName: Resource Group where the resource is
Resource: Name of the resource
ResourceType: Type of the resource
ResourceLocation: Location where the resource is
Cost M-1: Cost of the resource from previous month in currency specified in column "Currency"
Cost M: Cost of the resource from current month in currency specified in column "Currency"
Currency: Currency of cost from columns "Cost M-1" and "Cost"
Cost Variation: variation of Cost between "Cost M" and "Cost M-1"
Variation in Percent: variation of cost in percent between "Cost M-1" and "Cost M"


** Recommended tree structure **
root
|
|_Scripts
|_|_Get-AzCostVariation
|_|_|_Get-AzCostVariation.json
|_|_|_Get-AsCostVariation.ps1
|_|_|_readme.md
|
|_Data
|_|_GetAzCostVariation
|_|_|_CostManagement_M.csv
|_|_|_CostManageemtn_M-1.csv
|_|_|_Get-AzCostVariation.csv (result file)
|_|_|_Get-AzCostVariation.log (log file)

