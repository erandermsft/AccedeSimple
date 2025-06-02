param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentName string
param caeRegistryPullIdentityId string
param containerRegistryName string
param webui_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: containerAppsEnvironmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'webui'
  location: location
  tags: union(tags, { 'azd-service-name': 'webui' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities:  { 
      '${caeRegistryPullIdentityId}': {} // This is the identity used for pulling images from ACR
    } 
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress:{
        external: true
        targetPort: 80
        transport: 'http'
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
          image: webui_containerimage
          name: 'webui'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'BACKEND_URL'
              value: 'https://backend.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'PORT'
              value: '80'
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
