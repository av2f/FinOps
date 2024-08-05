import csv

def get_billing_account(csvfile, billing_id):
#
  billing_csv = [] 
  billing_to_add = ['88998888', 'CAP TRANSPORT S.A.']
  with open(csvfile, newline='') as f:
    reader = csv.reader(f, delimiter = ';')
    next(reader)  # skip the header row
    for row in reader:
        billing_csv.append(row[0])
        print(row[0])
  """
  for item in billing_id:
    if (item not in billing_csv):
      with open(csvfile, 'a') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(billing_to_add)
  """

#
def main():
  csvfile = "C:\\Users\\fparment\\Documents\\AzFinOps\\Data\\AzureDataSource\\BillingAccount.csv"
  billing_id = ['88991105', '88998888']
  get_billing_account(csvfile, billing_id)

  
main()      