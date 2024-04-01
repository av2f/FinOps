import requests
import json
import pandas as pd

df= pd.DataFrame(
  {
    "Name": [
    "Braund, Mr. Owen Harris",
    "Allen, Mr. William Henry",
    "Bonnell, Miss. Elizabeth",
    ],
    "Age": [22, 35, 58],
    "Sex": ["male", "male", "female"],
  }
)
# print(df)
# print(df["Age"].describe())

# data = requests.get('https://min-api.cryptocompare.com/data/histoday?fsym=BTC&tsym=ETH&limit=30&aggregate=1&e=CCCAGG')\
#                         .json()['Data']

api_url = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview"
query = "armRegionName eq 'southcentralus' and armSkuName eq 'Standard_NP20s' and priceType eq 'Consumption'" # and contains(meterName, 'Spot')"
currency = "'EUR'"
api_url += '&currencyCode=' + currency
# query = "ServiceName eq 'Virtual Machines' and armRegionName eq 'westeurope'"
response = requests.get(api_url, params={'$filter': query})
# json_data = json.loads(response.text)
json_data = response.json()
dt = pd.json_normalize(json_data['Items'])

nextPage = json_data['NextPageLink']


while(nextPage):
  response = requests.get(nextPage)
  # json_data = json.loads(response.text)
  json_data = response.json()
  nextPage = json_data['NextPageLink']

# print(nextPage)


                    
print(dt)