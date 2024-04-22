Name    : Get-AzAhb.ps1
Version : 1.2

** Description **
Help to optimize Azure Hybrid Benefit (AHB) management

Build a .csv file that contains for each Windows VMs:
  - Subscription Name
  - Subscription Id
  - Resource Group Name
  - VM Name
  - Location
  - PowerState
  - OS Type
  - OS Name (when specified in Azure)
  - License Type: 
    - if "Windows_Server" then AHB is applied
    - if "Windows_Client" then Azure Virtual Desktop is applied
  - Size of VM
  - Number of Cores of VMs
  - RAM of VMs
  - Tag Environment (if exists and specified in the Json file parameter)
  - Tag Availability (if exists and specified in the Json file parameter)
  - Calculate for each VMs:
    - Average CPU usage in percentage during the retention days indicated in the Json parameter file
    - Average Memory usage in percentage during the retention days indicated in the Json parameter file
  - Calculate if AHB applied
    - Number of AHB cores consumed
    - Number of AHB licenses consumed
    - Number of AHB cores wasted (based on Number of cores by licenses specified in the Json file parameter)
    - Number of AHB cores wasted when VM is in powerstate "Deallocated"
in result file GetAzAhb[mmddyyyyhhmmss].csv
  
For more information, type Get-Help .\Get-AzAhb.ps1 [-detailed | -full]

Global variables are stored in .\GetAzAhb.json and must be adapted accordingly

** Created by **
Author: Frederic Parmentier
Date: 04-10-2024

** Updates **
Updated date  : 04-17-2024
Updated by    : Frederic Parmentier
Update done   :
 - Add function GetTimeGrain to build the TimeSpan of TimeGrain

Updated date  : 04-22-2024
Updated by    : Frederic Parmentier
Update done   :
 - Improve time to retrieve of VMs informations
 - fix bug for AvgCpuUsage and AvgMemUsage calculation to avoid division by zero