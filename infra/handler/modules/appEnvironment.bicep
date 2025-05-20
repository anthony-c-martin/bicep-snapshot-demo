import { ResourceInfo } from '../../shared/types.bicep'

param location string
param name string

@secure()
param logWorkspaceCustomerId string

@secure()
param logWorkspaceSharedKey string

param subnetResourceId string

resource appEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: name
  location: location
  properties: {
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: subnetResourceId
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspaceCustomerId
        sharedKey: logWorkspaceSharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    zoneRedundant: true
  }
}

output resource ResourceInfo = { id: appEnvironment.id, name: appEnvironment.name }
output staticIp string = appEnvironment.properties.staticIp
