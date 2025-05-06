param name string
param location string
param tags object

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
  }
}

output id string = storageAccount.id
output name string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
