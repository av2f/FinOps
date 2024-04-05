$pathFile = "C:\Users\fparment\Documents\AzFinOps\Data\AlstomSubscriptions.csv"

$listSubscriptions = Import-Csv -Path $pathFile -Delimiter "," | Select-Object SubscriptionName
Write-Host $listSubscriptions.Count

[Object[]]$subscriptions

foreach($subscription in $listSubscriptions){
  if ($subscription -match '=([\w\W]*)\(([\w-]*)\)') {
    $subscriptions += @(
    [PSCustomObject]@{
      Name = $Matches.1
      Id = $Matches.2
    }
    )
    Write-Host $Matches.1 " - " $Matches.2
  }
  # $subscriptionArray = $subscription.SubscriptionName.Split('(')
  # $subscriptionArray[1] = $subscriptionArray[1].Substring(0,$subscriptionArray[1].Length-1)
  # Write-Host $subscriptionArray[0], $subscriptionArray[1], $subscription.EnrollmentAccountName
}

foreach ($subscription in $subscriptions) {
  Write-Host $subscription.Name " - " $subscription.Id
}