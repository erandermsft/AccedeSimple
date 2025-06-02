using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'MY_ENV')
param location = readEnvironmentVariable('AZURE_LOCATION', 'swedencentral')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')

var containerRegistryServer = readEnvironmentVariable('CAE_AZURE_CONTAINER_REGISTRY_ENDPOINT', '')

param webui_containerimage = readEnvironmentVariable('WEBUI_CONTAINERIMAGE', '${containerRegistryServer}/accede/webui:1.0')
param backend_containerimage = readEnvironmentVariable('BACKEND_CONTAINERIMAGE', '${containerRegistryServer}/accede/backend:1.0')
param mcpserver_containerimage = readEnvironmentVariable('MCP_SERVER_CONTAINERIMAGE', '${containerRegistryServer}/accede/mcp-server:1.0')
param localguide_containerimage = readEnvironmentVariable('LOCALGUIDE_CONTAINERIMAGE', '${containerRegistryServer}/accede/localguide:1.0')
