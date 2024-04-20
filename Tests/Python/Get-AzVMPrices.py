#!/usr/bin/env python3
import requests
import json
import pandas as pd
from tabulate import tabulate

def build_pricing_table(json_data, table_data):
    for item in json_data['Items']:
        meter = item['meterName']
        table_data.append([item['armSkuName'], item['retailPrice'], item['currencyCode'], item['unitOfMeasure'], item['armRegionName'], meter, item['productName']])
        
def main():
    table_data = []
    table_data.append(['SKU', 'Retail Price', 'Unit of Measure', 'Region', 'Meter', 'Product Name'])
    
    api_url = "https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview"
    # query = "armRegionName eq 'southcentralus' and armSkuName eq 'Standard_NP20s' and priceType eq 'Consumption' and contains(meterName, 'Spot')"
    currency = "'EUR'"
    api_url += '&currencyCode=' + currency
    query = "ServiceName eq 'Virtual Machines' and armRegionName eq 'westeurope'"
    response = requests.get(api_url, params={'$filter': query})
    json_data = json.loads(response.text)

    build_pricing_table(json_data, table_data)
    nextPage = json_data['NextPageLink']
    
    while(nextPage):
        response = requests.get(nextPage)
        json_data = json.loads(response.text)
        nextPage = json_data['NextPageLink']
        build_pricing_table(json_data, table_data)

    # print(table_data)
    print(tabulate(table_data, headers='firstrow', tablefmt='psql'))
    
if __name__ == "__main__":
    main()