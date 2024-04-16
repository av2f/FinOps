<#
  Name    : Get-SubscriptionsCsv.ps1
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 04/07/2024
  
  Updated date  :
  Updated by    :
  Update done   : 
  
  Transform a .csv file of subscriptions downloaded from Cost Management/Cost analysis with parameters:
    - Group by: Subscriptions
    - Granularity: None
    - Table
  The format retrieved for subscription name is : "subscription name(subscription Id)"
  The script creates a new .csv file splitting the column "Subscription name" into 2 columns:
    - Name;Id
  
  Adapt:
    - $pathFileSource to specify the directory and the file name of the .csv file source
    - $pathFileTArget to specify the directory and the file name of the .csv file target.
  
  Example: .\Get-SubscriptionsCsv.ps1
#>

$pathFileSource = "C:\Users\fparment\Documents\AzFinOps\Data\Alstom\cost-analysis.csv"
$pathFileTarget = "C:\Users\fparment\Documents\AzFinOps\Data\Alstom\subscriptions.csv"

$listSubscriptions = Import-Csv -Path $pathFileSource -Delimiter "," | Select-Object SubscriptionName
Write-Host "Start Processing for $($listSubscriptions.Count) subscriptions"

[Object[]]$subscriptions

$arraySubscriptions = @()

# Remove $csvResFile if already exists
if (Test-Path -Path $pathFileTarget -PathType Leaf) {
  Remove-Item -Path $pathFileTarget -Force
}

foreach($subscription in $listSubscriptions){
  if ($subscription -match '=([\w\W]*)\(([\w-]*)\)') {
    $subscriptions += @(
      [PSCustomObject]@{
        Name = $Matches.1
        Id = $Matches.2
      }
    )
  }
  
}
$arraySubscriptions += $subscriptions
$arraySubscriptions | Export-Csv -Path $pathFileTarget -Delimiter ";" -NoTypeInformation -Append
Write-Host "File $($pathFileTarget) is ready."
Write-Host "Process ended..."

<# --------------
# Test read target .csv file
$subscriptions = @()
$subscriptions = Import-Csv -Path $pathFileTarget -Delimiter ";"
foreach ($subscription in $subscriptions) {
  Write-Host $subscriptions.name " - " $subscription.Id
}
---------------#>
