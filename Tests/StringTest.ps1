# Retrieve global variables from json file
$globalVar = Get-Content -Raw -Path ".\Tests.json" | ConvertFrom-Json

[Object[]]$array = @()
# $array = $globalVar.tagsToCheck | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

$resourceId = "/subscriptions/4884d89c-a754-4f44-a84e-7313ad1ad116/resourceGroups/sdc4-08696-prod-rg/providers/Microsoft.Compute/virtualMachines/srsdc408696w001"
$resource = (Get-AzResource -ResourceId $resourceId | Select-Object -Property Name, ResourceType, Location, ResourceId, Tags)

$tags = @{}
$finOpsTags = $globalVar.finOpsTags.split(",")

$badTagValue = @{}
$nbOfBadValue = 0

$scope = $globalVar.patternTagValues
$array = $scope | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
foreach($item in $array) {
  Write-Host $scope.$item.type
}

if ($resource.Tags.Count -ne 0) {
  foreach ($key in $resource.Tags.keys) {
    $tags.Add($key, $resource.Tags[$key])
  }

  # find if FinOps Tag exists
  foreach($key in $tags.keys) {
    if ($key -cin $finOpsTags) {
      Write-Host "J'ai trouve $key"
      # le Tag fait-il parti d'un check particulier?
      $itemFound = $false
      foreach($item in $array) {
        if ($item -ceq $key) {
          $boolBadValue = $false
          switch ($globalVar.tagsToCheck.$item.type)
          {
            "list"
            {
              $listValue = $($globalVar.tagsToCheck.$item.value).split(",")
              if ($($tags[$key]) -cnotin $listValue) {
                $boolBadValue = $true
              }
            }
            "regex"
            {
              if ($($tags[$key]) -notmatch $($globalVar.tagsToCheck.$item.value)) {
                $boolBadValue = $true
              }
            }
            "string"
            {
              if ($($tags[$key]) -cne $($globalVar.tagsToCheck.$item.value)) {
                $boolBadValue = $true
              }
            }
          }
          if ($boolBadValue) {
            $nbOfBadValue += 1
            $badTagValue.Add($key,$($globalVar.tagsToCheck.$item.errorMessage))
          }
          # exit from the foreach loop
          $itemFound = $true
          break
        }
      }
      if (-not $itemFound) {
        if ([string]::IsNullOrEmpty($($tags[$key]).Trim())) {
          $nbOfBadValue += 1
          $badTagValue.Add($key,"undefined")
        }
      }
    }
  }
  Write-Host "il y $nbOfBadValue erreurs"
}


if ($globalVar.tagCheckValue.ToUpper() -eq 'Y') {
  # Write-Host "aller je traite"
  # $array = @{}
  # $array = $globalVar.tagsToCheck | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
  foreach($item in $array) {
    Write-Host $item
    Write-Host $globalVar.tagsToCheck.$item.type
    Write-Host $globalVar.tagsToCheck.$item.value
    Write-Host $globalVar.tagsToCheck.$item.errorMessage
  }
}





<#
$string = "Environment,AIPCode,AIPName,AIPOwner,AIPCriticality,Customer,DepartmentName,Owner,Supported,SLA,ServiceWindows,IsItemizable"
# $string2 = "Environment","AIPCode","AIPName","AIPOwner","AIPCriticality","Customer","DepartmentName","Owner","Supported","SLA","ServiceWindows","IsItemizable"
$hash = @{}
$a="Environment"
$c= @()
$c = $string.split(",")
Write-Host $c.GetType()
$b="environment"

foreach ($c1 in $c) {
  write-Host $c1
}

$d = @()
$d += "Toto"
$d += "titi"

$d | Sort-Object

$e = "{" + ($d -join ',') + "}"

$myString = "dddd"
Write-host $myString.Length


Write-Host $e
# Write-Host $string2

if ($a -cin $c) {
  Write-Host "$a found"
}
else { Write-Host "$a not found"}



$code = "123443"

$match = "^([0-9]{5})$"

if ($code -match $match) {
  Write-Host "yes match"
}
else {
  Write-Host "No ne match pas"
}
#>
