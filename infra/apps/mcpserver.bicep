param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentName string
param caeRegistryPullIdentityId string
param containerRegistryName string
param founderyHubName string
param mcpserver_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource foundryHub 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: founderyHubName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: containerAppsEnvironmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource mcpServerUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-mcpserver'
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpserver' })
}

resource openai_CognitiveServicesOpenAIContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    foundryHub.id,
    mcpServerUserAssignedIdentity.name,
    subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  )
  properties: {
    principalId: mcpServerUserAssignedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'a001fd3d-188f-4b5d-821b-7da978bf7442'
    )
    principalType: 'ServicePrincipal'
  }
  scope: foundryHub
}

resource mcpserver 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'mcpserver'
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpserver' })
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8080
        transport: 'http'
        allowInsecure: true
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: caeRegistryPullIdentityId
        }
      ]
    }
    environmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          image: mcpserver_containerimage
          name: 'mcpserver'
          env: [
            {
              name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_EMIT_EXCEPTION_LOG_ATTRIBUTES'
              value: 'true'
            }
            {
              name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_EMIT_EVENT_LOG_ATTRIBUTES'
              value: 'true'
            }
            {
              name: 'OTEL_DOTNET_EXPERIMENTAL_OTLP_RETRY'
              value: 'in_memory'
            }
            {
              name: 'ASPNETCORE_FORWARDEDHEADERS_ENABLED'
              value: 'true'
            }
            {
              name: 'ConnectionStrings__openai'
              value: 'https://${foundryHub.name}.cognitiveservices.azure.com'
            }
            {
              name: 'MODEL_NAME'
              value: 'gpt-4.1'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: mcpServerUserAssignedIdentity.properties.clientId
            }
            {
              name: 'LOGGING__LOGLEVEL__Microsoft.Extensions.AI'
              value: 'Trace'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mcpServerUserAssignedIdentity.id}': {}
      '${caeRegistryPullIdentityId}': {}
    }
  }
}

output mcpServerUserAssignedIdentityId string = mcpServerUserAssignedIdentity.id
output mcpServerContainerAppName string = mcpserver.name
