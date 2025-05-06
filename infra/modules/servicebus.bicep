param name string
param location string
param tags object

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

// Topic for customer orders
resource customerOrdersTopic 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' = {
  parent: serviceBus
  name: 'topic-customer-orders'
  properties: {
    enablePartitioning: true
  }
}

// Topic for router orders
resource routerOrderTopic 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' = {
  parent: serviceBus
  name: 'topic-router-orders'
  properties: {
    enablePartitioning: true
  }
}

// Queue for notifications
resource notificationQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBus
  name: 'notification'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxSizeInMegabytes: 1024
    maxDeliveryCount: 10
    enablePartitioning: true
  }
}

// Subscription for stock availability check
resource ordersTopicSubscriptionStock 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = {
  parent: customerOrdersTopic
  name: 'sub-order-stock'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
  }
}

// Subscription for router order processing
resource routerOrdersTopicSubscriptionOrder 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = {
  parent: routerOrderTopic
  name: 'sub-order-router'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
  }
}

resource routerOrdersTopicSubscriptionOrderFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-01-01-preview' = {
  parent: routerOrdersTopicSubscriptionOrder
  name: 'InstockFalseFilter'
  properties: {
    correlationFilter: {
      properties: {
        instock: 'false'
      }
    }
    filterType: 'CorrelationFilter'
  }
}

// Subscription for tech scheduling
resource techScheduleSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = {
  parent: routerOrderTopic
  name: 'sub-tech-schedule'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
  }
}

resource techScheduleSubscriptionFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-01-01-preview' = {
  parent: techScheduleSubscription
  name: 'InstockTrueFilter'
  properties: {
    correlationFilter: {
      properties: {
        instock: 'true'
      }
    }
    filterType: 'CorrelationFilter'
  }
}

output id string = serviceBus.id
output name string = serviceBus.name
output fullyQualifiedNamespace string = '${serviceBus.name}.servicebus.windows.net'
