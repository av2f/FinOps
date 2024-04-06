$pathFile = "C:\Users\fparment\Documents\AzFinOps\Data\GetAzAllTags\cost-analysis.csv"
$csvResFile = "C:\Users\fparment\Documents\AzFinOps\Data\GetAzAllTags\subscriptions.csv"

$listSubscriptions = Import-Csv -Path $pathFile -Delimiter "," | Select-Object SubscriptionName
Write-Host "Start Processing of $($listSubscriptions.Count) subscriptions"

[Object[]]$subscriptions

$arraySubscriptions = @()

# Remove $csvResFile if already exists
if (Test-Path -Path $csvResFile -PathType Leaf) {
  Remove-Item -Path $csvResFile -Force
}

$cpt = 0
foreach($subscription in $listSubscriptions){
  Write-Host "subscription $cpt"
  $cpt += 1
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
$arraySubscriptions | Export-Csv -Path $csvResFile -Delimiter ";" -NoTypeInformation -Append
Write-Host "Process ended..."

$subscriptions = @()
# Test lecture
$subscriptions = Import-Csv -Path $csvResFile -Delimiter ";"
foreach ($subscription in $subscriptions) {
  Write-Host $subscriptions.name " - " $subscription.Id
}
