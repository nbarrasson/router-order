param name string
param location string
param tags object

// Parameters for external service dependencies
param applicationInsightsConnectionString string
param workflowStorageConnectionString string
param serviceBusNamespace string
param apimSubscriptionKey string

@description('Name of the environment that can be used as part of resource names')
param environmentName string

param abbrs object

// Logic App service plan
resource logicAppServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${name}'
  location: location
  tags: tags
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  properties: {
    reserved: false
  }
}

// Logic App
resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: logicAppServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        { name:'AzureFunctionsJobHost__extensionBundle__version'
          value:'[1.*, 2.0.0)'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: workflowStorageConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: workflowStorageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'apiManagement_ApiId'
          value: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ApiManagement/service/${abbrs.apiManagementService}${environmentName}/apis/stock-management'
        }
        {
          name: 'apiManagement_SubscriptionKey'
          value: apimSubscriptionKey
        }
        {
          name: 'apiManagement_BaseUrl'
          value: 'https://${abbrs.apiManagementService}${environmentName}.azure-api.net/stock-management'
        }
        {
          name: 'routerOrderApiUrl'
          value: 'https://${name}.azurewebsites.net'
        }
        {
          name: 'serviceBus_fullyQualifiedNamespace'
          value: serviceBusNamespace
        }        
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
    }
  }
}

output id string = logicApp.id
output name string = logicApp.name
output defaultHostName string = logicApp.properties.defaultHostName
output identityPrincipalId string = logicApp.identity.principalId
