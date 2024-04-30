Set-AzContext -Subscription "4997b8fa-9e72-4621-84a8-d7132db3210f"
$vm = (Get-AzVM -ResourceId "/subscriptions/4997b8fa-9e72-4621-84a8-d7132db3210f/resourceGroups/SDC6-10084-PROD-RG/providers/Microsoft.Compute/virtualMachines/srsdc610084w003" |
  Select-Object -Property @{l="Publisher";e={$_.StorageProfile.ImageReference.Publisher}}, @{l="Offer";e={$_.StorageProfile.ImageReference.Offer}}
)

Write-Host $vm.Publisher " _ " $vm.Offer