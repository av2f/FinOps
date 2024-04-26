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
