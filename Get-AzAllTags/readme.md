Name    : Get-AzAllTags.ps1
Version : 1.3

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
  + NbOfBadValue: From the declared FinOps Tags presents, give the number of tags that have a bad value
    The -1 value means there was no checking (typically when no FinOps tags declared)
  + BadValueFinOpsTags: indicates the tags with bad values
  + TagsDefined: list of Tags defined with name and value in Json format

** Usage **
Prerequisites:
- Module az* must be installed : https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-12.0.0&tabs=powershell&pivots=windows-psgallery
- Prior running the script, you must connect to Azure with the command : Connect-AzAccount

- Ensure to set up correctly the Json parameter file

- Running the script : type the command ".\Az-AllTags.ps1

  ** Updates **
Updated date  : 05-17-2024
Updated by    : Frederic Parmentier
Update done   :
 - Add analyze of Tag values
 - 2 New columns Added in csv result file :
  + NbOfBadValue : Number of bad value from FinOps tags defined
  + BadValueFinOpsTags : List of tags that have bad value

- Add parameters in Json file parameter :
  + tagCheckValue : Y|N. if set to "Y" perform the checking of values
  + patternTagValues : Defined pattern to find specific value for a tag
    Example :
    "Environment": {   => Name of the tag to check
      "type": "list", => type of value to search (list = list of value, regex = regex pattern, string = string to search)
      "value": "Prod,Pre-prod,Qual,Dev,Test,Training,Sandbox,Uat", => value(s) to search
      "errorMessage": "Bad value" => error message to write in csv result file if bad value
    }