# Set-AzBillingSyntesis.py
import pandas as pd
import json
import os
import re
import datetime

# Declare constant
JSON_FILE = 'Set-AzBillingSynthesis.json'

def read_json(file):
  with open(file, 'r') as f:
    return json.load(f)

def create_target_directory(directory):
  """
  Check if directory exists.
  If not the case, create it
  """
  if (not os.path.exists(directory)):
    try:
      os.mkdir(directory)
    except OSError as error:
      print(error)
      return False
  else:
    return True
  
def process_file(file_to_process, is_grouped):
  dtype_dict = {
    'BillingAccountId': 'str', 'BillingPeriodEndDate': 'str', 'AccountOwnerId': 'str', 'AccountName': 'str', 'SubscriptionName': 'str', 'MeterCategory': 'str', 'MeterSubCategory': 'str',
    'MeterName': 'str', 'Cost': 'float64', 'UnitPrice': 'float64', 'ResourceLocation': 'str', 'ConsumedService': 'str', 'ResourceName': 'str',
    'CostCenter': 'str', 'ResourceGroup': 'str', 'ReservationId': 'str', 'ReservationName': 'str',
    'ProductOrderId': 'str', 'ProductOrderName': 'str', 'Term': 'str', 'ChargeType': 'str', 'PayGPrice': 'float64',
    'PricingModel': 'str', 'benefitName': 'str'
  }

  df = pd.read_csv(file_to_process, dtype=dtype_dict, usecols=[
    'BillingAccountId', 'BillingPeriodEndDate', 'AccountOwnerId', 'AccountName', 'SubscriptionName', 'MeterCategory',
    'MeterSubCategory', 'MeterName', 'Cost', 'UnitPrice',	'ResourceLocation', 'ConsumedService', 'ResourceName',
    'CostCenter', 'ResourceGroup', 'ReservationId', 'ReservationName', 'ProductOrderId', 'ProductOrderName', 'Term',
    'ChargeType', 'PayGPrice', 'PricingModel', 'benefitName'
  ])

  if (is_grouped):
    return df.groupby([
      'BillingAccountId', 'BillingPeriodEndDate', 'AccountOwnerId', 'AccountName', 'SubscriptionName', 'ResourceName',
      'MeterCategory', 'MeterSubCategory', 'MeterName', 'UnitPrice', 'ResourceLocation', 'ConsumedService', 'CostCenter',
      'ResourceGroup', 'ReservationId', 'ReservationName', 'ProductOrderId', 'ProductOrderName', 'Term', 'ChargeType',
      'PayGPrice', 'PricingModel', 'benefitName'
    ], as_index=False, dropna=False).agg(Total_Cost = ('Cost', 'sum'))
  else:
    return df

  
# main program
def main():
  # Retrieve directory of json file
  
  json_file =  os.path.join(os.path.dirname(__file__), JSON_FILE)
  if (not os.path.isfile(json_file)):
    print ('the file ' + json_file + ' was not found.')
    exit(1)
  
  print(json_file)

  # sera mis en parametres
  csv_source_file = 'Detail_Enrollment_88991105_202404_en.csv'

  # voir pour récupérer le chemin du script
  parameters = read_json(json_file)

  source_file = os.path.join(parameters['pathSource'], csv_source_file)
  # Check if file exists
  if (not os.path.isfile(source_file)):
    print ('the file ' + source_file + ' was not found.')
    exit(1)

  # Check if the target directory exists otherwise creates it
  if (not create_target_directory(parameters['pathTarget'])):
    print('Error : Error during the creation of the target directory.')
    exit(1)

  # Extract date from the file in format yyyymm
  split_file = csv_source_file.split('_')
  # Retrieve year and month in format yyyymm
  x = datetime.datetime.now().strftime('%Y%m')
  # Check if the source file is from current month
  if (split_file[3] == x):
    # current month : process file without grouping
    target_file = os.path.join(parameters['pathTarget'], parameters['targetDaily'])
    # Check if the target directory exists otherwise creates it
    if (not create_target_directory(target_file)):
      print('Error : Error during the creation of the target directory.')
      exit(1)
    # Create
    target_file = os.path.join(target_file, re.sub('Detail', 'Daily', csv_source_file))

    result_process = process_file(source_file, False)
  else:
    # process file grouping resources and calculating total cost
    
    target_file = os.path.join(parameters['pathTarget'], parameters['targetMonthly'])
    # Check if the target directory exists otherwise creates it
    if (not create_target_directory(target_file)):
      print('Error : Error during the creation of the target directory.')
      exit(1)
    # Create file result
    target_file = os.path.join(target_file, re.sub('Detail', 'Monthly', csv_source_file))
    
    result_process = process_file(source_file, True)
  
  # Write result
  result_process.to_csv(target_file, sep=',', index=False)
  
  print(target_file)


main()