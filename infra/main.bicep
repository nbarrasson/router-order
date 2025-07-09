targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of resource names')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Email address of the APIM publisher')
param apimPublisherEmail string

@description('Name of the APIM publisher')
param apimPublisherName string

var abbrs = loadJsonContent('./abbreviations.json')
var tags = { 'azd-env-name': environmentName }

// Resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Storage Account for Logic App workflows
module workflowStorage './modules/storage.bicep' = {
  name: 'workflow-storage'
  scope: resourceGroup
  params: {
    name: '${abbrs.storageAccountWorkflows}${replace(environmentName, '-', '')}'
    location: location
    tags: tags
  }
}

// Service Bus
module serviceBus './modules/servicebus.bicep' = {
  name: 'servicebus'
  scope: resourceGroup
  params: {
    name: '${abbrs.serviceBusNamespace}${environmentName}'
    location: location
    tags: tags
  }
}

// Application Insights
module applicationInsights './modules/application-insights.bicep' = {
  name: 'applicationinsights'
  scope: resourceGroup
  params: {
    name: '${abbrs.insightsComponents}${environmentName}'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: '${abbrs.logAnalyticsWorkspaces}${environmentName}'
  }
}

// API Management
module apiManagement './modules/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: '${abbrs.apiManagementService}${environmentName}'
    location: location
    tags: tags
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

// Logic App
module logicApp './modules/logic-app.bicep' = {
  name: 'logicapp'
  scope: resourceGroup
  params: {
    name: '${abbrs.logicApp}${environmentName}'
    location: location
    tags: tags
    applicationInsightsConnectionString: applicationInsights.outputs.applicationInsightsConnectionString
    workflowStorageConnectionString: workflowStorage.outputs.connectionString
    serviceBusNamespace: serviceBus.outputs.fullyQualifiedNamespace
    apimSubscriptionKey: apiManagement.outputs.subscriptionKey
    abbrs: abbrs
    environmentName: environmentName
  }
}

// Role assignments for Logic App managed identity
module sbSenderRoleAssignment 'modules/role-assignment.bicep' = {
  name: 'sb-sender-role-assignment'
  scope: resourceGroup
  params: {
    principalId: logicApp.outputs.identityPrincipalId
    roleDefinitionId: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
    targetId: serviceBus.outputs.id
  }
}

module sbReceiverRoleAssignment 'modules/role-assignment.bicep' = {
  name: 'sb-receiver-role-assignment'
  scope: resourceGroup
  params: {
    principalId: logicApp.outputs.identityPrincipalId
    roleDefinitionId: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' // Azure Service Bus Data Receiver
    targetId: serviceBus.outputs.id
  }
}

// Output values
output AZURE_LOCATION string = location
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name
