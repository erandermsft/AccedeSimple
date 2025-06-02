targetScope = 'subscription'

@description('Id of the user or app to assign application roles')
param principalId string = ''

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param environmentName string

@allowed(['eastus2','swedencentral','northcentralus','francecentral', 'eastus'])
@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string = 'swedencentral'
param resourceGroupName string = ''

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

@description('Whether the deployment is running on Azure DevOps Pipeline')
param runningOnAdo string = ''

param webui_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param mcpserver_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param backend_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param localguide_containerimage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var abbrs = loadJsonContent('./abbreviations.json')
var tags = { 'azd-env-name': environmentName }
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var principalType = empty(runningOnGh) && empty(runningOnAdo) ? 'User' : 'ServicePrincipal'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-03-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module foundry 'core/ai/foundry.bicep' = {
  name: 'foundry'
  scope: resourceGroup
  params: {
    hubName: 'foundry-${resourceToken}'
    projectName: 'project-${resourceToken}'
    principalId: principalId
    principalType: principalType
    location: location
  }
}

module blobStorage 'core/storage/blobstorage.bicep' = {
  name: 'blobStorage'
  scope: resourceGroup
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    principalId: principalId
    principalType: principalType
    location: location
  }
}

module monitoring 'core/monitoring/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    name: resourceToken
    location: location
    tags: tags
  }
}

module containerEnvironment 'core/containers/containerapps.bicep' = {
  name: 'containerAppsEnvironment'
  scope: resourceGroup
  params: {
    name: resourceToken
    location: location
    tags: tags
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.APPLICATION_INSIGHTS_NAME
  }
}

module backend 'apps/backend.bicep' = {
  name: 'backend'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    backendContainerAppImage: backend_containerimage
    containerAppsEnvironmentName: containerEnvironment.outputs.containerAppEnvironmentName
    storageAccountName: blobStorage.outputs.storageAccountName
    founderyHubName: foundry.outputs.foundryHubName
    containerRegistryName: containerEnvironment.outputs.containerRegistryName
    caeRegistryPullIdentityId: containerEnvironment.outputs.containerRegistryManagedIdentityId
  }
}

module webui 'apps/webui.bicep' = {
  name: 'webui'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    webui_containerimage: webui_containerimage
    containerAppsEnvironmentName: containerEnvironment.outputs.containerAppEnvironmentName
    caeRegistryPullIdentityId: containerEnvironment.outputs.containerRegistryManagedIdentityId
    containerRegistryName: containerEnvironment.outputs.containerRegistryName
  }
}

module mcpserver 'apps/mcpserver.bicep' = {
  name: 'mcpserver'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    mcpserver_containerimage: mcpserver_containerimage
    containerAppsEnvironmentName: containerEnvironment.outputs.containerAppEnvironmentName
    caeRegistryPullIdentityId: containerEnvironment.outputs.containerRegistryManagedIdentityId
    containerRegistryName: containerEnvironment.outputs.containerRegistryName
    founderyHubName: foundry.outputs.foundryHubName
  }
}

module localguide 'apps/localguide.bicep' = {
  name: 'localguide'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    localguide_containerimage: localguide_containerimage
    containerAppsEnvironmentName: containerEnvironment.outputs.containerAppEnvironmentName
    caeRegistryPullIdentityId: containerEnvironment.outputs.containerRegistryManagedIdentityId
    containerRegistryName: containerEnvironment.outputs.containerRegistryName
    founderyHubName: foundry.outputs.foundryHubName
  }
}


output AZURE_FOUNDRY_HUB_NAME string = foundry.outputs.foundryHubName
output AZURE_FOUNDRY_HUB_ID string = foundry.outputs.foundryHubId
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output OPENAI_CONNECTIONSTRING string = foundry.outputs.openAiEndpoint
output STORAGE_BLOBENDPOINT string = blobStorage.outputs.blobEndpoint
output AZURE_AI_FOUNDRY__PROJECT string = foundry.outputs.foundryProjectName

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerEnvironment.outputs.containerRegistryEndpoint
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = containerEnvironment.outputs.containerRegistryManagedIdentityId
output AZURE_CONTAINER_REGISTRY_NAME string = containerEnvironment.outputs.containerRegistryName
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerEnvironment.outputs.containerAppEnvironmentName
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerEnvironment.outputs.containerAppEnvironmentId
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = containerEnvironment.outputs.containerAppEnvironmentDefaultDomain

output BACKEND_IDENTITY_CLIENTID string = backend.outputs.backendIdentityClientId
output BACKEND_CONTAINER_APPS_NAME string = backend.outputs.backendContainerAppName

output MCPSERVER_IDENTITY_CLIENTID string = mcpserver.outputs.mcpServerUserAssignedIdentityId
output MCPSERVER_CONTAINER_APPS_NAME string = mcpserver.outputs.mcpServerContainerAppName

output CAE_AZURE_CONTAINER_REGISTRY_NAME string = containerEnvironment.outputs.containerRegistryName
output CAE_AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerEnvironment.outputs.containerRegistryEndpoint
output CAE_AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = containerEnvironment.outputs.containerRegistryManagedIdentityId
output CAE_AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = containerEnvironment.outputs.containerAppEnvironmentDefaultDomain
output CAE_AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerEnvironment.outputs.containerAppEnvironmentId
