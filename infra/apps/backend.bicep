param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentName string
param storageAccountName string
param caeRegistryPullIdentityId string
param containerRegistryName string
param founderyHubName string
param backendContainerAppImage string = 'mcr.microsoft.com/azuredocs/azure-ai-foundry-backend:latest'

resource foundryHub 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: founderyHubName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: containerAppsEnvironmentName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource backendUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-backend'
  location: location
  tags: union(tags, { 'azd-service-name': 'backend' })
}

var aiUserRoleDefinition = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource azureAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryHub.id, backendUserAssignedIdentity.name, aiUserRoleDefinition)
  scope: foundryHub
  properties: {
    principalId: backendUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: aiUserRoleDefinition
  }
}

resource openai_CognitiveServicesOpenAIContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryHub.id, backendUserAssignedIdentity.name, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442'))
  properties: {
    principalId: backendUserAssignedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
    principalType: 'ServicePrincipal'
  }
  scope: foundryHub
}

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'backend'
  location: location
  tags: union(tags, { 'azd-service-name': 'backend' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities:  { 
      '${backendUserAssignedIdentity.id}': {}
      '${caeRegistryPullIdentityId}': {} // This is the identity used for pulling images from ACR
    } 
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress:{
        external: true
        targetPort: 8080
        transport: 'http'
        corsPolicy: {
          allowedOrigins: [
            'https://*.${containerAppsEnvironment.properties.defaultDomain}'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
        }
      }        
      registries: [
        {
          server: acr.properties.loginServer
          identity: caeRegistryPullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          image: backendContainerAppImage
          name: 'backend'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
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
              name: 'services__mcpserver__http__0'
              value: 'http://mcpserver.internal.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'services__mcpserver__https__0'
              value: 'https://mcpserver.internal.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'services__localguide__http__0'
              value: 'http://localguide.internal.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'services__localguide__https__0'
              value: 'https://localguide.internal.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'ConnectionStrings__uploads'
              value: storageAccount.properties.primaryEndpoints.blob
            }
            {
              name: 'MODEL_NAME'
              value: 'gpt-4.1'
            }
            {
              name: 'AZURE_SUBSCRIPTION_ID'
              value: subscription().subscriptionId
            }
            {
              name: 'AZURE_RESOURCE_GROUP'
              value: resourceGroup().name
            }
            {
              name: 'AZURE_AI_FOUNDRY_PROJECT'
              value: foundryHub.name
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: backendUserAssignedIdentity.properties.clientId
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
        maxReplicas: 1
      }
    }
  }
}

output backendIdentityClientId string = backendUserAssignedIdentity.properties.clientId
output backendContainerAppName string = app.name
