import { UserAssignedIdentity, ResourceInfo, CopilotHandlerConfig } from '../../shared/types.bicep'
import { replaceMultiple } from '../../shared/helpers.bicep'

param isTestEnvironment bool
param apiManagementResource ResourceInfo
param containerAppEndpoint string
param handlerConfig CopilotHandlerConfig

// The value 'organizations' is a well known tenant for any Microsoft Entra directory.
// We use it in non-prod environments to support at least two tenant IDs. For example, Portal uses AME tenant to integrate with our DF environment.
var aadTenantId = isTestEnvironment ? 'organizations' : tenant().tenantId

var policies = {
  handler: loadTextContent('./apiPolicy-handler.xml')
}

resource service 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apiManagementResource.name
}

resource basePolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: service
  name: 'policy'
  properties: {
    value: loadTextContent('apiPolicyBase.xml')
    format: 'rawxml'
  }
}

resource topLevelApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: service
  name: 'top-level-api'
  properties: {
    displayName: 'Top Level APIs'
    apiRevision: '1'
    subscriptionRequired: false
    path: ''
    protocols: [
      'https'
    ]
    isCurrent: true
  }
}

resource topLevelApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: topLevelApi
  name: 'policy'
  properties: {
    value: replaceMultiple(policies.handler, {
      '$REPLACE_AAD_TENANTID': aadTenantId
      '$REPLACE_BACKEND_ENDPOINT': containerAppEndpoint
      '$REPLACE_AUDIENCES_XML': join(map(handlerConfig.authorizedAudiences, audience => '<audience>${audience}</audience>'), '')
      '$REPLACE_CLIENT_APPIDS_XML': join(map(handlerConfig.authorizedAppIds, appId => '<application-id>${appId}</application-id>'), '')
    })
    format: 'rawxml'
  }
}

resource healthCheckOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: topLevelApi
  name: 'health-check'
  properties: {
    displayName: 'Health Check API'
    method: 'GET'
    urlTemplate: '/healthcheck'
  }
}

resource handlerApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: service
  name: 'bicep-api'
  properties: {
    displayName: 'Handler APIs'
    apiRevision: '1'
    subscriptionRequired: false
    path: 'bicep'
    protocols: [
      'https'
    ]
    isCurrent: true
  }
}

resource handlerPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: handlerApi
  name: 'policy'
  properties: {
    value: replaceMultiple(policies.handler, {
      '$REPLACE_AAD_TENANTID': aadTenantId
      '$REPLACE_BACKEND_ENDPOINT': '${containerAppEndpoint}/bicep'
      '$REPLACE_AUDIENCES_XML': join(map(handlerConfig.authorizedAudiences, audience => '<audience>${audience}</audience>'), '')
      '$REPLACE_CLIENT_APPIDS_XML': join(map(handlerConfig.authorizedAppIds, appId => '<application-id>${appId}</application-id>'), '')
    })
    format: 'rawxml'
  }
}

resource handlerCopilotPost 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: handlerApi
  name: 'copilot-post'
  properties: {
    displayName: 'Copilot API'
    method: 'POST'
    urlTemplate: '/copilot'
  }
}
