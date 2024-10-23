# robocopy 'C:\Users\fparment\Documents\Dossiers Clients' 'C:\Users\fparment\Documents\testrobocopy' /e /unilog:robocopy.log /np /bytes /v

$logfile = 'C:\Users\fparment\Documents\robocopy\logsrobocopy.log'
$tempLog = 'C:\Users\fparment\Documents\robocopy\temp_robocopy.log'


# read $logFile removing blank lines with result in tempLog
Get-Content $logfile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Set-Content $tempLog
$arrayLog = Get-Content $tempLog

foreach ($line in $arrayLog) {
  write-host $line
}

write-host ($arrayLog | Measure-Object).Count


# Penser a supprimer $templog
