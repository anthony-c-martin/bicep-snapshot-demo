import { UserAssignedIdentity, ContainerImage, CosmosDbIngress, CopilotHandlerConfig, ResourceInfo } from '../shared/types.bicep'

param namePrefix string
param nameSuffix string
param isTestEnvironment bool
param dataImage ContainerImage
param registryName string
param backendImage ContainerImage
param openAiLocation string
param cosmosDbIngress CosmosDbIngress
param handlerConfig CopilotHandlerConfig

// container apps and container jobs have restrictions on name lengths.
// as a result, we need to be able to shorten the names in certain regions.
param containerAppPrefix string

var names = {
  openAI: '${namePrefix}-openai-${nameSuffix}'
  searchService: '${namePrefix}-searchservice-${nameSuffix}'
  laWorkspace: '${namePrefix}-workspace-${nameSuffix}'
  appInsights: '${namePrefix}-appinsights-${nameSuffix}'
  appEnvironment: '${namePrefix}-cae-${nameSuffix}'
  apiManagement: '${namePrefix}-apim-${nameSuffix}'
  api: '${namePrefix}-api-${nameSuffix}'
  containerApp: '${containerAppPrefix}-ca-${nameSuffix}'
  containerJob: '${containerAppPrefix}-job-${nameSuffix}'
  appConfig: '${namePrefix}-appconfig-${nameSuffix}'
}

var location = resourceGroup().location

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: registryName
}

module containerIdentity 'modules/identity.bicep' = {
  name: 'containerIdentity'
  params: {
    name: '${namePrefix}-ca-identity-${nameSuffix}'
    location: location
  }
}

module apimIdentity 'modules/identity.bicep' = {
  name: 'apimIdentity'
  params: {
    name: '${namePrefix}-apim-identity-${nameSuffix}'
    location: location
  }
}

module dataIdentity 'modules/identity.bicep' = {
  name: 'dataIdentity'
  params: {
    name: '${namePrefix}-data-identity-${nameSuffix}'
    location: location
  }
}

module cosmosDb 'modules/cosmosDb.bicep' = {
  name: 'cosmosDb'
  params: {
    // avoid using zone-redundant in test environments
    isZoneRedundant: !isTestEnvironment
    namePrefix: namePrefix
    nameSuffix: nameSuffix
    location: location
    cosmosDbIngress: cosmosDbIngress
  }
}

module openAI 'modules/openAI.bicep' = {
  name: 'openAI'
  params: {
    name: names.openAI
    location: openAiLocation
  }
}

module searchService 'modules/searchService.bicep' = {
  name: 'searchService'
  params: {
    name: names.searchService
    location: location
    openAI: openAI.outputs.resource
    cosmosDb: cosmosDb.outputs.resource
  }
}

module appConfig 'modules/config.bicep' = {
  name: 'appConfig'
  params: {
    name: names.appConfig
    location: location
    config: {
      APPINSIGHTS_INSTRUMENTATION_KEY: appInsights.outputs.instrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
      AI_SEARCH_ENDPOINT: searchService.outputs.searchServiceEndpoint
      AI_SEARCH_INDEX: 'quickstart-index'
      ENABLE_LOCAL_LOG: 'true'
      AZURE_OPENAI_API_ENDPOINT: openAI.outputs.openAIEnpoint
      AZURE_OPENAI_API_VERSION: '2024-02-15-preview'
      AZURE_OPENAI_COMPLETION_DEPLOYMENT: 'gpt-4o-mini'
      AZURE_OPENAI_EMBEDDING_DEPLOYMENT: 'text-embedding-ada-002'
      AZURE_OPENAI_MAX_TOKENS: '13000'
      COSMOS_URL: cosmosDb.outputs.cosmosUrl
      COSMOS_DATABASE_NAME: cosmosDb.outputs.databaseName
      COSMOS_CONTAINER_NAME: cosmosDb.outputs.containerName
      COSMOS_CONNECTION_STRING: cosmosDb.outputs.connectionString
    }
  }
}

module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    namePrefix: namePrefix
    location: location
    nameSuffix: nameSuffix
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: names.laWorkspace
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

var logWorkspaceCustomerId = logAnalytics.properties.customerId
var logWorkspaceSharedKey = logAnalytics.listKeys().primarySharedKey

module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  params: {
    name: names.appInsights
    location: location
    workspaceResourceId: logAnalytics.id
  }
}

module appEnvironment 'modules/appEnvironment.bicep' = {
  name: 'appEnvironment'
  params: {
    name: names.appEnvironment
    location: location
    logWorkspaceCustomerId: logWorkspaceCustomerId
    logWorkspaceSharedKey: logWorkspaceSharedKey
    subnetResourceId: vnet.outputs.acaSubnet.id
  }
}

module apiManagement 'modules/apiManagement.bicep' = {
  name: 'apiManagement'
  params: {
    name: names.apiManagement
    location: location
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    appInsights: appInsights.outputs.appInsights
    identity: apimIdentity.outputs.identity
    subnetResourceId: vnet.outputs.apimSubnet.id
    // avoid using zone-redundant in test environments
    isZoneRedundant: !isTestEnvironment
  }
}

module containerApp 'modules/containerApp.bicep' = {
  name: 'containerApp'
  params: {
    name: names.containerApp
    location: location
    image: backendImage
    registry: { id: registry.id, name: registry.name }
    appConfig: appConfig.outputs.resource
    openAI: openAI.outputs.resource
    searchService: searchService.outputs.resource
    containerIdentity: containerIdentity.outputs.identity
    appEnvironment: appEnvironment.outputs.resource
    appEnvironmentIp: appEnvironment.outputs.staticIp
    appConfigEndpoint: appConfig.outputs.endpoint
  }
}

module dataJob 'modules/job.bicep' = {
  name: 'dataJob'
  params: {
    appEnvironment: appEnvironment.outputs.resource
    name: names.containerJob
    location: location
    image: dataImage
    identity: dataIdentity.outputs.identity
    registry: { id: registry.id, name: registry.name }
    searchService: searchService.outputs.resource
    cosmosDb: cosmosDb.outputs.resource
    envVars: {
      AZURE_CLIENT_ID: dataIdentity.outputs.identity.clientId
      AZURE_OPENAI_ENDPOINT: openAI.outputs.openAIEnpoint
      MODEL_DEPLOYMENT_NAME_EMBEDDING: 'text-embedding-ada-002'
      BICEP_COPILOT_SEARCH_SERVICE_ENDPOINT: searchService.outputs.searchServiceEndpoint
      COSMOS_CONNECTION_STRING: cosmosDb.outputs.connectionString
      COSMOS_URL: cosmosDb.outputs.cosmosUrl
      DATABASE_NAME: cosmosDb.outputs.databaseName
      CONTAINER_NAME: cosmosDb.outputs.containerName
      QUICKSTART_REPO_URL: 'https://github.com/Azure/azure-quickstart-templates'        
    }
  }
}

module api 'modules/apis.bicep' = {
  name: 'apis'
  params: {
    isTestEnvironment: isTestEnvironment
    apiManagementResource: apiManagement.outputs.resource
    containerAppEndpoint: containerApp.outputs.endpoint
    handlerConfig: handlerConfig
  }
}

output apiBaseUrl string = apiManagement.outputs.gatewayUrl
output apiManagementResource ResourceInfo = apiManagement.outputs.resource
output containerAppEndpoint string = containerApp.outputs.endpoint
