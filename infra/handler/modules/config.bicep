import { ResourceInfo } from '../../shared/types.bicep'

param name string
param location string
@secure()
param config {
  *: string
}

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-09-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
}

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-10-01-preview' = [for item in items(config): {
  parent: appConfig
  // the '$common' syntax adds a label named 'common' to the key
  name: '${item.key}$common'
  properties: {
    value: item.value
  }
}]

output endpoint string = appConfig.properties.endpoint
output resource ResourceInfo = { id: appConfig.id, name: appConfig.name }
