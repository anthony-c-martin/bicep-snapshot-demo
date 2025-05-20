import { UserAssignedIdentity } from '../shared/types.bicep'
import { Contributor } from '../shared/builtInRoles.bicep'

param registryName string
param imagePushIdentity string

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: tenant()
  name: Contributor
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: imagePushIdentity
  location: resourceGroup().location
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: resourceGroup().location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    zoneRedundancy: 'Enabled'
    policies: {
      retentionPolicy: {
        // this controls how long untagged images are retained
        // it has no effect on retention of tagged images
        days: 2
        status: 'enabled'
      }
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  scope: acr
  name: guid(resourceGroup().id, contributorRoleDefinition.id, registryName, imagePushIdentity)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
