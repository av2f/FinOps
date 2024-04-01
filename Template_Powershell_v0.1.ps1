<#
  Name    : <Script Name>
  Author  : <Surname> <Name>
  Version : x.x
  Creation Date : MM/dd/yyyy
  
  Updated date  :
  Updated by    :
  Update done   :

  <brief description of the functionality of the script>
  For more information, type Get-Help .\<script name>.ps1 [-detailed | -full]
#>

<#
  to display messages on the console with the -Verbose option
  use Write-Verbose "Your text"
#>

<# -----------
  Declare input parameters
----------- #>
[cmdletBinding()]

param()

<# Example to be removed :
param(
  [Parameter(Mandatory = $false)]
  [String]$TagName
)
#>

# Disable breaking change Warning messages in Azure Powershell
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

function NameOfFunction{
  <#
    <Description>
    Input :
      - <Input parameter(s)> : <Explain for what>
    Output : 
      - <Output parameter(s)>
  #>
  
  # Declare input parameter(s)
  param()
  
  <# Example to be removed :
  param(
    [String] $directory
  )
  #>

  # function code
}

<# -----------
  Main Program
----------- #>
Write-Verbose "Starting processing..."

<#
  Your code
#>

<# 
  if your script build a csv file, use code below replacing
  - <Directory name for results> by your directory name to store results
  - <File name for results> by the file name for results
#>
# Generate the csv file
Write-Verbose "Building csv result file..."
if((CreateDirectoryResult '<Directory name for results>')){
  $csvFile = '.\<Directory name for results>\' + (CreateChronoFile '<File name for results>') + '.csv'
}
$arraySubscriptionOwner | Export-Csv -Path $csvFile -Delimiter ";" -NoTypeInformation
Write-Verbose "File $csvFile is available."

<# -----------
  End Main Program
----------- #>

<# -----------
  Get-Help Informations (used for Get-Help)
----------- #>

<#
  .SYNOPSIS
  This script retrieves Subscription owner(s) from Access Control (IAM) / Role Assignments and a tag if one is defined.
  
  .DESCRIPTION
  The Get-OwnerSubscription script searches owner(s) of all subscriptions from IAM and a tag if one is defined and store it 
  in the file .\GetOwnerSubscription\GetOwnerSubscriptionmmddyyyyhhmmss.csv.
  The format of .csv file is :
  - if one tag defined : SubscriptionName;TagName;Tag_Value;Owner
  - if no tag defined : SubscriptionName;Owner
  
  Prerequisites :
  - Az module must be installed
  - before running the script, connect to Azure with the cmdlet "Connect-AzAccount"

  .INPUTS
  Optional : -TagName <Tag_Name>. If one tag contains the owner, indicate this tag name.
  Optional : -Verbose to have progress informations on console

  .OUTPUTS
  GetOwnerSubscriptionmmddyyyyhhmmss.csv file with results.

  .EXAMPLE
  .\Get-OwnerSubscription.ps1 : Retrieve Owner(s) in IAM.
  .\Get-OwnerSubscription.ps1 -TagName 'tag name' : Retrieve Owner(s) in both IAM and Tag Name indicated.
  .\Get-OwnerSubscription.ps1 -Verbose : Execute the script without output progress informations on console.

  .NOTES
  Before executing the script, ensure that you are connected to Azure account by the function Connect-AzAccount.
#>