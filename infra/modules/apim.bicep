param name string
param location string
param tags object
@description('Email address of the publisher')
param publisherEmail string
@description('Name of the publisher')
param publisherName string

// API Management instance
resource apiManagement 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Router Order Product
resource routerOrderProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  parent: apiManagement
  name: 'router-order'
  properties: {
    displayName: 'Router Order'
    description: 'Product for Router Order operations'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

// Stock Management API
resource stockManagementApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apiManagement
  name: 'stock-management'
  properties: {
    displayName: 'Stock Management API'
    path: 'stock-management'
    protocols: [
      'https'
    ]
    format: 'openapi'
    value: loadTextContent('../../api/stock-management/openapi.yaml')
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

// Mock response policy for Stock Management API
resource stockManagementPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: stockManagementApi
  name: 'policy'
  properties: {
    value: '''<policies>
    <inbound>
        <base />
        <mock-response status-code="200" content-type="application/json" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>'''
    format: 'xml'
  }
}

// Associate Stock Management API with Router Order Product
resource apiProductAssociation 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: routerOrderProduct
  name: stockManagementApi.name
}

// Create subscription for the product
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apiManagement
  name: 'router-order-subscription'
  properties: {
    displayName: 'Router Order Subscription'
    scope: routerOrderProduct.id
    state: 'active'
  }
}

// Add schema for order validation
resource orderSchema 'Microsoft.ApiManagement/service/schemas@2024-06-01-preview' = {
  parent: apiManagement
  name: 'order-schema'
  properties: {
    schemaType: 'json'
    document: {
      value: {
        type: 'object'
        properties: {
          order: {
            type: 'object'
            properties: {
              orderId: { type: 'string' }
              orderDate: { type: 'string' }
              customer: {
                type: 'object'
                properties: {
                  accountType: { type: 'string' }
                  companyName: { type: 'string' }
                  contactPerson: {
                    type: 'object'
                    properties: {
                      firstName: { type: 'string' }
                      lastName: { type: 'string' }
                      email: { type: 'string' }
                      jobTitle: { type: 'string' }
                    }
                    required: ['firstName', 'lastName', 'email', 'jobTitle']
                  }
                  billingAddress: {
                    type: 'object'
                    properties: {
                      street: { type: 'string' }
                      city: { type: 'string' }
                      postalCode: { type: 'string' }
                      country: { type: 'string' }
                    }
                    required: ['street', 'city', 'postalCode', 'country']
                  }
                }
                required: ['accountType', 'companyName', 'contactPerson', 'billingAddress']
              }
              contractDetails: {
                type: 'object'
                properties: {
                  contractId: { type: 'string' }
                  servicePlan: { type: 'string' }
                  commitmentPeriod: { type: 'string' }
                  monthlyFee: { type: 'number' }
                }
                required: ['contractId', 'servicePlan', 'commitmentPeriod', 'monthlyFee']
              }
              product: {
                type: 'object'
                properties: {
                  type: { type: 'string' }
                  model: { type: 'string' }
                  version: { type: 'string' }
                  features: {
                    type: 'array'
                    items: { type: 'string' }
                  }
                  quantity: { type: 'integer' }
                  unitPrice: { type: 'integer' }
                }
                required: ['type', 'model', 'version', 'features', 'quantity', 'unitPrice']
              }
              delivery: {
                type: 'object'
                properties: {
                  method: { type: 'string' }
                  trackingNumber: { type: 'string' }
                  estimatedDeliveryDate: { type: 'string' }
                  deliveryAddress: {
                    type: 'object'
                    properties: {
                      street: { type: 'string' }
                      city: { type: 'string' }
                      postalCode: { type: 'string' }
                      country: { type: 'string' }
                    }
                    required: ['street', 'city', 'postalCode', 'country']
                  }
                  deliveryInstructions: { type: 'string' }
                }
                required: ['method', 'trackingNumber', 'estimatedDeliveryDate', 'deliveryAddress', 'deliveryInstructions']
              }
              payment: {
                type: 'object'
                properties: {
                  method: { type: 'string' }
                  poNumber: { type: 'string' }
                  totalPrice: { type: 'integer' }
                  installationFee: { type: 'integer' }
                  discount: {
                    type: 'object'
                    properties: {
                      type: { type: 'string' }
                      amount: { type: 'integer' }
                      description: { type: 'string' }
                    }
                    required: ['type', 'amount', 'description']
                  }
                }
                required: ['method', 'poNumber', 'totalPrice', 'installationFee', 'discount']
              }
            }
            required: ['orderId', 'orderDate', 'customer', 'contractDetails', 'product', 'delivery', 'payment']
          }
        }
        required: ['order']
      }
    }
  }
}

output id string = apiManagement.id
output name string = apiManagement.name
output gatewayUrl string = apiManagement.properties.gatewayUrl
output subscriptionKey string = listSecrets('${resourceGroup().id}/providers/Microsoft.ApiManagement/service/${name}/subscriptions/router-order-subscription', '2022-08-01').primaryKey
