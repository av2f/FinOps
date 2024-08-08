"""
  Name    : Set-AzBillingSynthesis.py
  Author  : Frederic Parmentier
  Version : 1.0
  Creation Date : 08/05/2024

  ****** PUT DESCRIPTION *******
"""

import pandas as pd
import csv
import json
import os
import re
import datetime
import time

# Declare constant
JSON_FILE = 'Set-AzBillingSynthesis.json'

def read_json(file):
  """
    Retrieve parameters in the Json parameters file
    Input:
      - file: Json parameters file
    Output: 
      - dictionnary with key:value from Json parameters file
  """
  with open(file, 'r') as f:
    return json.load(f)

def create_target_directory(directory):
  """
    Check if directory exists.
    If not the case, create it
  """
  if not os.path.exists(directory):
    try:
      os.mkdir(directory)
    except OSError as error:
      print(error)
      return False
  else:
    return True
  
def calculate_duration(start, end):
  """
    Calculate and format the duration of execution of script
    Input:
      - start: script start time in seconds
      - end: script end time
    Output: 
      - script execution time with format hh:mm:ss
  """
  time_elapse = time.gmtime(end-start)
  return time.strftime('%Hh:%Mm:%Ss', time_elapse)

def load_file(source_file, separator, csv_encoding):
  dtype_dict = {
      'BillingAccountId': 'str', 'BillingAccountName': 'str', 'BillingPeriodEndDate': 'str', 'BillingProfileId': 'str', 'BillingProfileName': 'str',
      'AccountOwnerId': 'str', 'AccountName': 'str', 'SubscriptionName': 'str', 'Date': 'str', 'MeterCategory': 'str', 'MeterSubCategory': 'str',
      'MeterName': 'str', 'Cost': 'float64', 'UnitPrice': 'float64', 'BillingCurrency': 'str', 'ResourceLocation': 'str', 'ConsumedService': 'str',
      'ResourceName': 'str', 'AdditionalInfo': 'str', 'Tags': 'str', 'CostCenter': 'str', 'ResourceGroup': 'str', 'ReservationName': 'str',
      'ProductOrderName': 'str', 'Term': 'str', 'ChargeType': 'str', 'PayGPrice': 'float64', 'PricingModel': 'str'
    }

  return pd.read_csv(source_file, dtype=dtype_dict, sep=separator, encoding=csv_encoding, usecols=[
      'BillingAccountId', 'BillingAccountName', 'BillingPeriodEndDate', 'BillingProfileId', 'BillingProfileName',
      'AccountOwnerId', 'AccountName', 'SubscriptionName', 'Date', 'MeterCategory', 'MeterSubCategory',
      'MeterName', 'Cost', 'UnitPrice',	'BillingCurrency', 'ResourceLocation', 'ConsumedService',
      'ResourceName', 'AdditionalInfo', 'Tags', 'CostCenter', 'ResourceGroup', 'ReservationName',
      'ProductOrderName', 'Term', 'ChargeType', 'PayGPrice', 'PricingModel'
    ])

def synthesis_file(df, finops_tags):
  tags = finops_tags.split(',')
  return df.groupby([
  'BillingAccountId', 'BillingPeriodEndDate', 'BillingProfileId', 'AccountOwnerId',
  'AccountName', 'SubscriptionName', 'MeterCategory', 'MeterSubCategory',
  'MeterName', 'UnitPrice',	'ResourceLocation', 'ConsumedService',
  'ResourceName', 'AdditionalInfo', 'Tags', 'CostCenter', 'ResourceGroup', 'ReservationName',
  'ProductOrderName', 'Term', 'ChargeType', 'PayGPrice', 'PricingModel'] + tags, as_index=False, dropna=False).agg(Total_Cost = ('Cost', 'sum'))

def get_billing_account(csvfile, df):
  # Put description
  billing_csv = [] 
  ba = df[['BillingAccountId', 'BillingAccountName']]
  # Retrieve the billing_id
  billing_ids = ba['BillingAccountId'].unique()
  # 
  with open(csvfile, newline='') as f:
    reader = csv.reader(f, delimiter = ';')
    next(reader)  # skip the header row
    for row in reader:
        billing_csv.append(row[0])
  # if at least 1 item
  if len(billing_csv) > 0:
    for item in billing_ids:
      if item not in billing_csv:
        billing_id = ba[ba['BillingAccountId'] == item].iloc[0].tolist()
        with open(csvfile, 'a', newline='') as f:
          writer = csv.writer(f, delimiter=';')
          writer.writerow(billing_id)
  # else write all billing account
  else:
      for item in billing_ids:
        billing_id = ba[ba['BillingAccountId'] == item].iloc[0].tolist()
        with open(csvfile, 'a', newline='') as f:
          writer = csv.writer(f, delimiter=';')
          writer.writerow(billing_id)

def get_billing_profile(csvfile, df):
  # Put description
  billing_csv = [] 
  bp = df[['BillingProfileId', 'BillingProfileName', 'BillingCurrency']]
  # Retrieve the billing_id
  billing_ids = bp['BillingProfileId'].unique()
  # 
  with open(csvfile, newline='') as f:
    reader = csv.reader(f, delimiter = ';')
    next(reader)  # skip the header row
    for row in reader:
      billing_csv.append(row[0])
  # if at least 1 item
  if len(billing_csv) > 0:
    for item in billing_ids:
      if item not in billing_csv:
        billing_id = bp[bp['BillingProfileId'] == item].iloc[0].tolist()
        with open(csvfile, 'a', newline='') as f:
          writer = csv.writer(f, delimiter=';')
          writer.writerow(billing_id)
  # else write all billing account
  else:
      for item in billing_ids:
        billing_id = bp[bp['BillingProfileId'] == item].iloc[0].tolist()
        with open(csvfile, 'a', newline='') as f:
          writer = csv.writer(f, delimiter=';')
          writer.writerow(billing_id)

def get_sku(info, criteria):
  # Put Description
  new_info = ''
  str_info = str(info)
  if criteria in str_info:
    sku = re.search(rf"\"{re.escape(criteria)}\":\"([\w]*)\"", str_info)
    if sku:
      new_info = sku.group(1).strip()
  return new_info

def get_reservation_type(product):
  new_product = ''
  str_product = str(product)
  if len(str_product) > 3:
    str_product = str_product.replace(u'\xa0' , u'')
    reservation_type = re.search(r"^([\w -\/]*),", str_product)
    if reservation_type:
      new_product = reservation_type.group(1).strip()
  return new_product

def set_finops_tags(df, finops_tags):
  tags = finops_tags.split(',')
  for tag in tags:
    df[tag] = ''
  return df

def get_finops_tags(tags, list_tags):
  dic_tags = {}
  str_tags = str(tags)
  if len(str_tags) > 3:
    finops_tags = list_tags.split(',')
    for finops_tag in finops_tags:
      if finops_tag in str_tags:
        tag_value = re.search(rf"\"{re.escape(finops_tag)}\": \"([\w .@]*)\"", str_tags)
        if tag_value:
          dic_tags[finops_tag] = tag_value.group(1).strip()
  str_dic_tags = str(dic_tags)
  # if dic is empty
  if len(dic_tags) == 0:
    str_dic_tags = ""      
  return str_dic_tags

def set_finops_tag(tags, key_tag):
  tag_value = ''
  if len(tags) > 0:
    if key_tag in tags:
      value = re.search(rf"'{re.escape(key_tag)}': '([\w .@]*)'", tags)
      if value:
        tag_value = str(value.group(1).strip())
  return tag_value

#
# ---------------------- main program
def main():

  # Calculate time execution
  start = time.time()

  # === sera mis en parametres
  csv_source_file = 'Detail_Enrollment_88991105_202405_en.csv'

  # Check if Json file exists
  json_file =  os.path.join(os.path.dirname(__file__), JSON_FILE)
  if not os.path.isfile(json_file):
    print ('the file ' + json_file + ' was not found.')
    exit(1)

  # Retrieve parameters from Json file
  parameters = read_json(json_file)

  # --- Load source file and processing ---
  # Check if the source directory exists otherwise exit
  source_path = os.path.join(parameters['pathData'], parameters['pathDetailed'])
  if not os.path.exists(source_path):
    print('the directory ' + source_path + ' was not found.')
    exit(1)
  
  # Check if file exists
  source_file = os.path.join(source_path, csv_source_file)
  if not os.path.isfile(source_file):
    print ('the file ' + source_file + ' was not found.')
    exit(1)

  # Load the source file
  df = load_file(source_file, parameters['csvDetailedSeparator'], parameters['csvEncoding'])

  # Process in Billing Account
  account_file = os.path.join(parameters['pathData'], parameters['billingAccount'])
  if not os.path.isfile(account_file):
    print ('the file ' + account_file + ' was not found.')
    exit(1)
  get_billing_account(account_file, df)

  # Process in Billing Profile
  profile_file = os.path.join(parameters['pathData'], parameters['billingProfile'])
  if not os.path.isfile(profile_file):
    print ('the file ' + profile_file + ' was not found.')
    exit(1)
  get_billing_profile(profile_file, df)

  # Drop columns BillingAccountName, BillingProfileName, BillingCurrency
  df.drop(columns=['BillingAccountName', 'BillingProfileName', 'BillingCurrency'], inplace=True)

  # Extract SKU of VM in additionnalInfo column
  df['AdditionalInfo'] = df['AdditionalInfo'].apply(get_sku, args=(parameters['additionalInfo'],))
  
  # Extract Reservation type in ProductOrderName
  df['ProductOrderName'] = df['ProductOrderName'].apply(get_reservation_type)

  # Add FinOps Tags in df
  df = set_finops_tags(df, parameters['finopsTags'])

  # Extract FinOps tags
  df['Tags'] = df['Tags'].apply(get_finops_tags, args=(parameters['finopsTags'],))

  # Grouping of rows
  df = synthesis_file(df, parameters['finopsTags'])

  # Assign values to finOps tags columns
  finops_tags = parameters['finopsTags'].split(',')
  for finops_tag in finops_tags:
    df[finops_tag] = df['Tags'].apply(set_finops_tag, args=(finops_tag,))

  # Drop column 'Tags'
  df.drop(columns=['Tags'], inplace=True)

  # --- Write result file ---
  # Check if the target directory exists otherwise creates it
  target_path = os.path.join(parameters['pathData'], parameters['pathSynthesis'])
  if not create_target_directory(target_path) :
    print('Error : Error during the creation of the target directory.')
    exit(1)

  # Extract date from the file in format yyyymm
  split_file = csv_source_file.split('_')
  
  # Retrieve year and month in format yyyymm
  current_month = datetime.datetime.now().strftime('%Y%m')
  
  # if current month, process file without grouping
  if split_file[3] == current_month:
    target_file = os.path.join(target_path, parameters['targetDaily'])
    # Check if the target directory exists otherwise creates it
    if not create_target_directory(target_file):
      print('Error : Error during the creation of the target directory.')
      exit(1)
    target_file = os.path.join(target_file, re.sub('Detail', 'Daily', csv_source_file))
  # process file grouping resources and calculating total cost
  else:
    target_file = os.path.join(target_path, parameters['targetMonthly'])
    # Check if the target directory exists otherwise creates it
    if not create_target_directory(target_file):
      print('Error : Error during the creation of the target directory.')
      exit(1)
  
  # Create file result
  target_file = os.path.join(target_file, re.sub('Detail', 'Monthly', csv_source_file))
  
  # Write result file
  df.to_csv(target_file, sep=',', index=False)
  
  print(target_file)
  
  # Calulate time execution
  end = time.time()
  duration = calculate_duration(start, end)
  print ('Script executed in ' + duration)

main()