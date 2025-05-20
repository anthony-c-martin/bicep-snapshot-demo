import { ResourceInfo } from '../../shared/types.bicep'

param name string
param location string
param workspaceResourceId string

resource component 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    RetentionInDays: 90
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output instrumentationKey string = component.properties.InstrumentationKey
output connectionString string = component.properties.ConnectionString
output appInsights ResourceInfo = { id: component.id, name: component.name }
