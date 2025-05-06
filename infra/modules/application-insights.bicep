@description('Name of Application Insights')
param name string

@description('Location to deploy the resource')
param location string

@description('Tags to add to resources')
param tags object

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

output applicationInsightsId string = appInsights.id
output applicationInsightsName string = appInsights.name
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
output applicationInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output logAnalyticsWorkspaceId string = logWorkspace.id
