Name    : Get-AzAllTags.ps1
Version : 1.2

** Description **
Retrieve Tags defined in Subscriptions, Resource Groups and Resources, and store them in .\GetAzAllTags\GetAzAllTags[mmddyyyyhhmmss].csv
For more information, type Get-Help .\Get-AzAllTags.ps1 [-detailed | -full]

Global variables are stored in .\GetAzVmUsage.json and must be adapted accordingly

** Created by **
Author: Frederic Parmentier
Date: 02-01-2024

** Updates **
Updated date  : 04-05-2024
Updated by    : Frederic Parmentier
Update done   :
 - Re-design script by functions
 - Add Json parameter file

** Updates **
Updated date  : 04-26-2024
Updated by    : Frederic Parmentier
Update done   :
 - Re-design csv results file with following columns:
  + Subscription Name
  + Subscription Id
  + ResourceGroup Name
  + Resource Name
  + Resource Type
  + Resource Id
  + Location
  + Status:
    - "FinOps tags present": All FinOps Tags defined are present
    - "Missing FinOps tags": Some FinOps tags are missing
    - "No tags defined": No FinOps tags defined
  + NbOfMissingFinOpsTags: number of FinOps tags which are not defined
  + MissingFinOpsTags: List of missing FinOps tags
  + TagsNameDefined: List of tags name defined
  + TagsDefined: list of Tags defined with name and value in Json format