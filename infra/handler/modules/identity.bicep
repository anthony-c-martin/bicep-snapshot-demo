import { UserAssignedIdentity } from '../../shared/types.bicep'

param name string
param location string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
}

output identity UserAssignedIdentity = {
  resourceId: identity.id
  principalId: identity.properties.principalId
  clientId: identity.properties.clientId
  tenantId: identity.properties.tenantId
}
