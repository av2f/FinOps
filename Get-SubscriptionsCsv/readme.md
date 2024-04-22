Name    : Get-SubscriptionsCsv.ps1
Version : 1.0

** Description **
Transform a .csv file of subscriptions downloaded from Cost Management/Cost analysis with parameters:
    - Group by: Subscriptions
    - Granularity: None
    - Table
The format retrieved for subscription name is : "subscription name(subscription Id)"
The script creates a new .csv file splitting the column "Subscription name" into 2 columns:
  - Name;Id
  
Adapt:
 - $pathFileSource to specify the directory and the file name of the .csv file source
 - $pathFileTArget to specify the directory and the file name of the .csv file target.
  
Example: .\Get-SubscriptionsCsv.ps1


** Created by **
Author: Frederic Parmentier
Date: 04-07-2024

** Updates **