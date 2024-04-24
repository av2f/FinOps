# Pour Test
<#
$subscriptionName = "EA AMER DXC Cloud Ops managed services for Alstom"
$subscriptionId = "6e029caa-ce75-433f-9c26-e1ab25e41080"
$resourceGroupName = "sdc5-04319-prod-rg"
$vmName = "srsdc504319w002"
$resourceId = "/subscriptions/6e029caa-ce75-433f-9c26-e1ab25e41080/resourceGroups/sdc5-04319-prod-rg/providers/Microsoft.Compute/virtualMachines/srsdc504319w002"

Set-AzContext -Subscription $subscriptionId | Out-Null

Write-Host "Recuperation des tags de $subscriptionName / $resourceGroupName / $resourceId"

# Initiate Hash array
$tags = @{}

# $tags = (Get-AzTag -ResourceId $resourceId)
$resource = (Get-AzResource -Name $vmName | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags)
foreach ($key in $resource.Tags.Keys) {
  $tags.Add($key, $resource.Tags[$key])
}
Write-Host $tags.Count
$tagsJson = $tags | ConvertTo-Json -Compress
Write-Host $tagsJson.GetType()
foreach ($key in $tags.Keys) {
  Write-Host $key
}

Write-Host $tagsJson
#>

function CreateExcelFile
{
  <#
   Create an Excel file with the result csv files
    Input:
      - $excelFileName: Excel file name
      - $csvFiles: Array of csv files with WorkSheetName
        format: WorksheetName:CsvFileName
      - $removeCsvFile: If set to $true, remove csv files after the export in the Excel file
    Output: 
      - the Excel file $excelFileName
  #>
  param(
    [string]$excelFileName,
    [hashtable]$csvFiles,
    [Boolean]$removeCsvFile
  )
  
  # Create Excel File and Remove csv files if $removeCsvFile is set to True
  foreach($key in $csvFiles) {
    Write-Host $csvFiles[$key] " - " $key
  }
}

$csvFileToExcel = @{}
$csvFileToExcel.Add("AzTags", "C:/Users/fparment/Documents/AzFinOps/Data/GetAzAllTags/GetAzTags")
$csvFileToExcel.Add("AzNoTags", "C:/Users/fparment/Documents/AzFinOps/Data/GetAzAllTags/GetAzNoTags")

CreateExcelFile -excelFileName $xlsResFile -csvFiles $csvFileToExcel -removeCsvFile $true
