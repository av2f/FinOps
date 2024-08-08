# Convert Date in date format
df['Date'] = pd.to_datetime(df['Date'], format = '%m/%d/%Y')

def uniformize_tags(df):
  """
    Retrieve the most recent value of the column Tags for a resource and
    assigns it to all other lines matching this resource
    Input: df the dataframe
    Output: uniformize tags of resources
  """
  # Retrieve list of resources
  u_resources = df['ResourceName'].unique()
  # if at least 1 resource
  if len(u_resources) > 0:
    # Extract resources with date and tags
    resources = df[['Date', 'ResourceName', 'Tags']]
    c = 0
    for u_resource in u_resources:
      s_resource = resources[resources['ResourceName'] == u_resource]
      # if at least 2 rows
      if len(s_resource) > 2:
        # sort by date descending
        s_resource = s_resource.sort_values(by='Date', ascending=False)
        # Keep the 1st row
        s_resource = s_resource.iloc[0]
        # Assigns value of tags to other rows with same resource
        df.loc[df['ResourceName'] == u_resource, 'Tags'] = s_resource['Tags']
        print(u_resource + ' - ' + str(s_resource['Tags']))
        c += 1
        if c % 100 == 0:
          msg = f'{c} resources processed...'
          print(msg)
          break
  return df