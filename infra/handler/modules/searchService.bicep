import { ResourceInfo } from '../../shared/types.bicep'
import { CognitiveServicesOpenAIUser, CosmosDbAccountReader, CosmosDbDataContributor } from '../../shared/builtInRoles.bicep'

param name string
param location string
param openAI ResourceInfo
param cosmosDb ResourceInfo

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  sku: {
    name: 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    //TODO: disable this and only allow private access from vnet
    publicNetworkAccess: 'enabled'
    semanticSearch: 'standard'
    disableLocalAuth: true
  }
}

resource cognitiveServicesOpenAIUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: CognitiveServicesOpenAIUser
}

resource openAIResource 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAI.name
}

resource roleAssignmentOpenAIUser 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: openAIResource
  name: guid(searchService.id, openAIResource.id, cognitiveServicesOpenAIUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIUserRole.id
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cosmosDbResource 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosDb.name
}

resource cosmosDbAccountReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: CosmosDbAccountReader
}

resource roleAssignmentCosmosDbAccountReader 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: cosmosDbResource
  name: guid(searchService.id, cosmosDbResource.id, cosmosDbAccountReaderRole.id)
  properties: {
    roleDefinitionId: cosmosDbAccountReaderRole.id
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// This is a data plane role definition for Cosmos DB (it is a child type of the database account)
resource cosmosDbDataContributerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' existing = {
   parent: cosmosDbResource
   name: CosmosDbDataContributor
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(searchService.id, cosmosDbResource.id, cosmosDbDataContributerRole.id)
  parent: cosmosDbResource
  properties: {
    roleDefinitionId: cosmosDbDataContributerRole.id
    principalId: searchService.identity.principalId
    scope: cosmosDbResource.id
  }  
}

// TODO: extract from resource body instead of hard-coding 
output searchServiceEndpoint string = 'https://${name}.search.windows.net' 
output resource ResourceInfo = { id: searchService.id, name: searchService.name }
output searchServicePrincipalId string = searchService.identity.principalId
