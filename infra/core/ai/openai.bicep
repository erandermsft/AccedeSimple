param name string
param location string = resourceGroup().location
param tags object = {}

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: 'OpenAI'
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 's0'
  }
}

resource deploymentLlm 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: 'gpt-4.1'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
    }
  }
  sku: {
    name: 'GlobalStandard'
    capacity: 100
  }
}

resource deploymentEmbedding 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: account
  name: 'text-embedding-3-small'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
    }
  }
  sku: {
    name: 'GlobalStandard'
    capacity: 20
  }
  dependsOn: [
    deploymentLlm
  ]
}
