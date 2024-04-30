Name    : Get-AzVmUsage.ps1
Version : 1.1.1

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

in result file GetAzVmUsage[mmddyyyyhhmmss].csv
  
For more information, type Get-Help .\Get-AzVmUsage.ps1 [-detailed | -full]

Global variables are stored in .\GetAzVmUsage.json and must be adapted accordingly

** Created by **
Author: Frederic Parmentier
Date: 04-02-2024

** Updates **
Updated date  : 04-20-2024
Updated by    : Frederic Parmentier
Update done   :
 - Improve function to retrieve VMs informations
 - Add a sanity check of list of subscriptions in .csv file removing deleted and disabled before starting process

Updated date  : 04-20-2024
Updated by    : Frederic Parmentier
Update done   :
 - Add function GetTimeGrain to build the TimeSpan of TimeGrain

Updated date  : 04-30-2024
Updated by    : Frederic Parmentier
Update done   :
 - Change operator for calculation of limitCountCpu and limitCountMem: "Greater than" instead of "Greater or Equal" than limit defined in json parameter file (limitCountCpu and limitCountMem)