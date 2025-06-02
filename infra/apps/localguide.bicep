
param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentName string
param caeRegistryPullIdentityId string
param containerRegistryName string
param founderyHubName string
param localguide_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource foundryHub 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: founderyHubName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: containerAppsEnvironmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource localguideUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-localguide'
  location: location
  tags: union(tags, { 'azd-service-name': 'backend' })
}

resource openai_CognitiveServicesOpenAIContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryHub.id, localguideUserAssignedIdentity.name, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442'))
  properties: {
    principalId: localguideUserAssignedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
    principalType: 'ServicePrincipal'
  }
  scope: foundryHub
}

resource localguide 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'localguide'
  location: location
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8000
        transport: 'http'
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
          image: localguide_containerimage
          name: 'localguide'
          env: [
            {
              name: 'OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED'
              value: 'true'
            }
            {
              name: 'PORT'
              value: '8000'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: 'https://${foundryHub.name}.cognitiveservices.azure.com'
            }
            {
              name: 'MODEL_NAME'
              value: 'gpt-4.1'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: localguideUserAssignedIdentity.properties.clientId
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
      '${localguideUserAssignedIdentity.id}': { }
      '${caeRegistryPullIdentityId}': { }
    }
  }
}
