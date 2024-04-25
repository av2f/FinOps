$string = "Environment,AIPCode,AIPName,AIPOwner,AIPCriticality,Customer,DepartmentName,Owner,Supported,SLA,ServiceWindows,IsItemizable"
# $string2 = "Environment","AIPCode","AIPName","AIPOwner","AIPCriticality","Customer","DepartmentName","Owner","Supported","SLA","ServiceWindows","IsItemizable"
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
$e = "{" + ($d -join ',') + "}"

$myString = "dddd"
Write-host $myString.Length


Write-Host $e
# Write-Host $string2

if ($a -cin $c) {
  Write-Host "$a found"
}
else { Write-Host "$a not found"}