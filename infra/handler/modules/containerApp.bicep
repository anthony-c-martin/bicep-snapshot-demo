import { UserAssignedIdentity, ContainerImage, ResourceInfo } from '../../shared/types.bicep'
import { AcrPull, AppConfigurationDataReader, CognitiveServicesOpenAIContributor, SearchIndexDataReader } from '../../shared/builtInRoles.bicep'

param name string
param location string
param appEnvironment ResourceInfo
param registry ResourceInfo
param appConfig ResourceInfo
param openAI ResourceInfo
param searchService ResourceInfo
param image ContainerImage
param appConfigEndpoint string
param containerIdentity UserAssignedIdentity
param appEnvironmentIp string

var ingressPort = 8000

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
  name: guid(containerIdentity.principalId, registryResource.id, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: containerIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource appConfigResource 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfig.name
}

resource appConfigurationDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: AppConfigurationDataReader
}

resource roleAssignmentConfigRead 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: appConfigResource
  name: guid(containerIdentity.principalId, appConfigResource.id, appConfigurationDataReaderRole.id)
  properties: {
    roleDefinitionId: appConfigurationDataReaderRole.id
    principalId: containerIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource openAIResource 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAI.name
}

resource cognitiveServicesOpenAIContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: CognitiveServicesOpenAIContributor
}

resource roleAssignmentOpenAIContributor 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: openAIResource
  name: guid(containerIdentity.principalId, openAIResource.id, cognitiveServicesOpenAIContributorRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIContributorRole.id
    principalId: containerIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceResource 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchService.name
}

resource searchIndexDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: SearchIndexDataReader
}

resource roleAssignmentSearchRead 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: searchServiceResource
  name: guid(containerIdentity.principalId, searchServiceResource.id, searchIndexDataReaderRole.id)
  properties: {
    roleDefinitionId: searchIndexDataReaderRole.id
    principalId: containerIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Environment variables for the container runtime')
var envVars = {
  AZURE_APPCONFIGURATION_ENDPOINT: appConfigEndpoint
  AZURE_CLIENT_ID: containerIdentity.clientId
  WEBSITE_AAD_ENABLE_MISE: 'true'
}

resource containerApp 'Microsoft.App/containerapps@2023-11-02-preview' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerIdentity.resourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: appEnvironment.id
    environmentId: appEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: ingressPort
        exposedPort: ingressPort
        transport: 'tcp'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: registryDnsName
          identity: containerIdentity.resourceId
        }
      ]
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${registryDnsName}/${image.name}:${image.tag}'
          name: 'handler'
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
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
      volumes: []
    }
  }
  dependsOn: [roleAssignmentAcrPull, roleAssignmentConfigRead]
}

output endpoint string = 'http://${appEnvironmentIp}:${ingressPort}'
