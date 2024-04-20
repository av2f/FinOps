# Modules pandas and openpyxl must be installed

import requests
import pandas as pd

# Define url
api_url = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview"

# Define options. if no option, put "option = {}"
option = {
  "meterRegion" : "primary",
  "currencyCode" : "EUR"
}

# Define query paramaters. if no param, put "query = {}"
query = {
  "ServiceName" : "Virtual Machines",
  "armRegionName" : "westeurope"
}

def CreateOption(option):
  stroption = ""
  # if dictionary option contains items
  if len(option) > 0:
    # Read each key and value of dictionary option
    for key,value in option.items():
      stroption += "&" + key + "=" + value
  return stroption

def CreateQuery(query):
  strQuery = ""
  # if dictionary query contains items
  if len(query) > 0:
    # Read each key and value of dictionary query
    for key,value in query.items():
      strQuery += key + " eq '" + value +"' and "
  # return strquery removing the last string " and "
  return strQuery[:-5]

def ResultApi(url, option, query):
  if option.strip():
    url += option 
  if query.strip():
    return requests.get(url, params={'$filter': query})
  else:
    return requests.get(url)
    
def main():
  jsonData = {}
  print(CreateOption(option))
  print(CreateQuery(query))
  response = ResultApi(api_url, CreateOption(option), CreateQuery(query))
  jsonData = response.json()
  
  nextPage = jsonData['NextPageLink']
  
  while(nextPage):
    response = requests.get(nextPage)
    jsonData2 = response.json()
    jsonData.update(jsonData2)
    nextPage = jsonData2['NextPageLink']
    print(nextPage)
  
  
  # print(json_data)
  dt = pd.json_normalize(jsonData['Items'])
  
  # Reste à faire la boucle des NextPageLink et ajouter à la dataframe pd.
  
  dt.to_excel("C:/AzurePrice.xlsx", sheet_name="Azure_price", index=False)

  # print(dt)
  # print(dt1)

  

if __name__ == "__main__":
    main()
