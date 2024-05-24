Name    : Get-AzDiskInfo.ps1
Version : 1.0

** Description **
Retrieve CPU and RAM usage for all VMs in subscriptions scope defined

Build a .csv file that contains for each Windows VMs:
  - Subscription Name
  - Resource Group Name
  - VM Name
  - Location
  - PowerState
  - OS Type
  - OS Name (when specified in Azure)
  - Size of VM
  - Number of Cores of VMs
  - RAM of VMs
  - Calculate for each VMs during the retention days and the time grain indicated un the Json parameter file:
    - CPU 
      + Average CPU usage in percentage
      + Max CPU usage in percentage
      + Min CPU usage in percentage
  
    - RAM
      + Average RAM usage in percentage
      + Max RAM usage in percentage
      + Min RAM usage in percentage

in result file Get-AzDiskInfo[mmddyyyyhhmmss].csv
  
For more information, type Get-Help .\Get-AzDiskInfo.ps1 [-detailed | -full]

Global variables are stored in .\Get-AzDiskInfo.json and must be adapted accordingly

** Created by **
Author: Frederic Parmentier
Date: 05-24-2024

** Updates **
Updated date  :
Updated by    :
Update done   :
