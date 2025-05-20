import { ResourceInfo, CosmosDbIngress } from '../../shared/types.bicep'

param namePrefix string
param nameSuffix string
param location string

param cosmosDbIngress CosmosDbIngress

var names = {
  account: '${namePrefix}-cosmosdb-${nameSuffix}'
  database: 'quickstarts'
  templatesContainer: 'templates'
}

// If access from all azure resources is requested, we'll update our ip list here:
var allowedIpAddresses = union(
  cosmosDbIngress.allowedIps, 
  cosmosDbIngress.allowAllAzureServiceIpAddresses ? ['0.0.0.0'] : []
)

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-03-15' = {
  name: names.account
  location: location
  properties: {
    enableAnalyticalStorage: false
    disableLocalAuth: true
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    publicNetworkAccess: 'Enabled'
    virtualNetworkRules: []
    ipRules: [
      for ipAddress in allowedIpAddresses: {
        ipAddressOrRange: ipAddress
      }
    ]
    disableKeyBasedMetadataWriteAccess: true
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-03-15' = {
  parent: cosmosAccount
  name: names.database
  properties: {
    resource: {
      id: names.database
    }
    options: {
      autoscaleSettings: {
        maxThroughput: 10000
      }
    }
  }
}

resource templatesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-03-15' = {
  parent: database
  name: names.templatesContainer
  properties: {
    resource: {
      id: names.templatesContainer
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
    }
  }
}

output cosmosUrl string = cosmosAccount.properties.documentEndpoint
output databaseName string = database.name
output containerName string = templatesContainer.name
output connectionString string = 'ResourceId=${cosmosAccount.id};Database=${database.name};IdentityAuthType=AccessToken'
output resource ResourceInfo = { id: cosmosAccount.id, name: cosmosAccount.name }
