import { UserAssignedIdentity, ContainerImage, ResourceInfo } from '../../shared/types.bicep'
import { AcrPull, AppConfigurationDataReader, CognitiveServicesOpenAIContributor, SearchIndexDataContributor, CosmosDbDataContributor, SearchSearviceContributor, ContainerJobContributor } from '../../shared/builtInRoles.bicep'

param appEnvironment ResourceInfo
param name string
param location string 
param image ContainerImage
param identity UserAssignedIdentity
param registry ResourceInfo
param searchService ResourceInfo
param cosmosDb ResourceInfo
param envVars object

var registryDnsName = '${image.registry}${environment().suffixes.acrLoginServer}'

resource registryResource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: registry.name
}

resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: AcrPull
}

resource roleAssignmentAcrPull 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: registryResource
  name: guid(identity.principalId, registryResource.id, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceResource 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchService.name
}

resource searchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: SearchIndexDataContributor
}

resource roleAssignmentSearchIndexDataContributer 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: searchServiceResource
  name: guid(identity.principalId, searchServiceResource.id, searchIndexDataContributorRole.id)
  properties: {
    roleDefinitionId: searchIndexDataContributorRole.id
    principalId: identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchSearviceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: SearchSearviceContributor
}

resource roleAssignmentSearchSearviceContributor 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: searchServiceResource
  name: guid(identity.principalId, searchServiceResource.id, searchSearviceContributorRole.id)
  properties: {
    roleDefinitionId: searchSearviceContributorRole.id
    principalId: identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cosmosDbResource 'Microsoft.DocumentDB/databaseAccounts@2023-03-15' existing = {
  name: cosmosDb.name
}
// This is a data plane role definition for Cosmos DB (it is a child type of the database account)
resource cosmosDbDataContributerRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' existing = {
   parent: cosmosDbResource
   name: CosmosDbDataContributor
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(identity.principalId, cosmosDbResource.id, cosmosDbDataContributerRole.id)
  parent: cosmosDbResource
  properties: {
    roleDefinitionId: cosmosDbDataContributerRole.id
    principalId: identity.principalId
    scope: cosmosDbResource.id
  }  
}

resource containerJob 'Microsoft.App/jobs@2024-03-01' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.resourceId}': {}
    }
  }
  properties: {
   environmentId: appEnvironment.id
   configuration: {
    replicaTimeout: 1800
    triggerType: 'Manual'
    registries: [
      {
        server: registryDnsName
        identity: identity.resourceId
      }
    ]
   } 
   template: {
     containers: [
        {
          image: '${registryDnsName}/${image.name}:${image.tag}'
          name: 'job'
          env: map(items(envVars), kvp => {
            name: kvp.key
            value: kvp.value
          })
          resources: {
            cpu: 4
            memory: '8Gi'
          }
        }
     ] 
   }
  } 
}

resource containerJobContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: ContainerJobContributor
}

resource roleAssignmentContainerJobRun 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: containerJob
  name: guid(identity.principalId, containerJob.id, containerJobContributorRole.id)
  properties: {
    roleDefinitionId: containerJobContributorRole.id
    principalId: identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource runContainerJob 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'runContainerJob'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.resourceId}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.61.0'
    forceUpdateTag: image.tag
    retentionInterval: 'PT1H'
    scriptContent: 'az containerapp job start --ids ${containerJob.id}'
  }
  dependsOn: [roleAssignmentContainerJobRun]
}
