Name    : Get-AzAhb.ps1
Version : 1.2
** Created by **
Author: Frederic Parmentier
Date: 04-10-2024

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

Global variables are stored in .\GetAzAhb.json and must be adapted accordingly:
{
  "pathResult": "D:/azFinOps/Data/GetAzAhb/", # Path to store result and log files
  "fileResult": "GetAzAhb",                   # Name of the result file
  "chronoFile": "Y",                          # Y = result and log files is built with a chrono in the format "mmddyyyyhhmmss", N = No chrono
  "generateLogFile": "Y",                     # Y = generate a log file, N = No log file
  "checkIfLogIn": "Y",                        # Y = Check first if already log in to Azure, N = No control
  "subscriptionsScope": {
    "scope": "All",                           # All = process on all Azure subecriptions, csv file in format "Name, Id"
    "delimiter": ";"                          # if csv file specified, define the delimiter
  },
  "osTypeFilter": "Windows",                  # Specify which OS type to filter for the result 
  "hybridBenefit": {
    "licenseType": "Windows_Server",          # LicenseType for Azure Hybrid Benefit
    "name": "Hybrid Benefit"
  },
  "virtualDesktop": {
    "licenseType": "Windows_Client",          # LicenseType for Azure Virtual desktop
    "name": "Azure Virtual Desktop"
  },
  "weightLicenseInCores": 8,                  # Specify the weight of a AHB license in cores
  "metrics": {
    "cpuUsage": "Percentage CPU",             # Define which field to search to calculate CPU usage
    "memoryAvailable": "Available Memory Bytes", # Define which field to search to calculate Memory usage
    "retentionDays": 30,                      # Define the retention in days to calcuate CPU and Memory usages
    "timeGrain": "01:00:00"                   # Define the timegrain to retrieve dataset of CPU and Memory usages
  },
  "limitCountCpu": 0,                         # Threshold to calculate the number of time the CPU reaches the value (Greater than)
  "tags": {
    "environment": "Environment",             # Specify the name of the tag that describes the environement
    "availability": "ServiceWindows"          # Specify the name of the tag that describes the availability
  },
  "saveEvery": 100                            # Specify a batch of how many records to write to the result file
}

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