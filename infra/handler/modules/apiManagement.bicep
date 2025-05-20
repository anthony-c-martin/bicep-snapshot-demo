import { UserAssignedIdentity, ResourceInfo } from '../../shared/types.bicep'

param location string
param name string
param identity UserAssignedIdentity

@secure()
param appInsightsInstrumentationKey string
param appInsights ResourceInfo

param subnetResourceId string

resource service 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Premium'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.resourceId}': {}
    }
  }
  properties: {
    publisherEmail: 'unizomb@microsoft.com'
    publisherName: 'unizomb'
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetResourceId
    }
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${name}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
        certificateSource: 'BuiltIn'
      }
    ]
  }
}

resource serviceLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  parent: service
  name: name
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: appInsights.id
  }
}

resource serviceDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = {
  parent: service
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    logClientIp: true
    loggerId: serviceLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

resource serviceDiagnosticsLogger 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = {
  parent: serviceDiagnostics
  name: name
}

output resource ResourceInfo = { name: service.name, id: service.id }
output gatewayUrl string = service.properties.gatewayUrl
