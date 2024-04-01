$path = "C:\Users\fparment\Documents\Formation\Azure Powershell\Azure FinOps\"
$csvfile = $path + "AlstomSubscriptions.csv"

$subscriptions = Import-Csv -Path $csvfile -Delimiter "," | Select-Object SubscriptionName, EnrollmentAccountName
Write-Host $subscriptions.Count

foreach($subscription in $subscriptions){
  if ($subscription -match '=([\w\W]*)\(([\w-]*)\)') {
    Write-Host $Matches.1
  }
  # $subscriptionArray = $subscription.SubscriptionName.Split('(')
  # $subscriptionArray[1] = $subscriptionArray[1].Substring(0,$subscriptionArray[1].Length-1)
  # Write-Host $subscriptionArray[0], $subscriptionArray[1], $subscription.EnrollmentAccountName
}