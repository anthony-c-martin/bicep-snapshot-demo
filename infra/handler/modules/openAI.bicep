import { ResourceInfo } from '../../shared/types.bicep'

//NOTE: No single region has all models available. 
//https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits#regional-quota-limits
// Bicep Copilot Infra:
// Dev Environment:  main location -> East US 2
// DF Environment:   main location -> West US 2, OpenAI location -> West US 3
// Prod (Global Region) Environment: main location -> West US 2, OpenAI location -> West US 3
// Prod (EU Region) Environment:     main location -> West Europe, OpenAI location -> Sweden Central
param location string
param name string

// The quota limit is per subscription. The following capacity values are roughly half of the limit so that
// we can afford to deploy two of the same models in the same subscription.
var models = [
  {
    name: 'gpt-4o-mini'
    capacity: 220
    version: '2024-07-18'
  }
  {
    name: 'text-embedding-ada-002'
    capacity: 120
    version: '2'
  }

  // The following 2 models are currently not available in westus3
  // {
  //   name: 'gpt-35-turbo-16k'
  //   capacity: 120
  //   version: '0613'
  // }
  // {
  //   name: 'text-embedding-3-small'
  //   capacity: 170
  //   version: '1'
  // }
]

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: name // This is NOT optional. Without this, the endpoint will be a different pattern and the deployed models are not usable.
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

@batchSize(1)
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for model in models: {
  parent: account
  name: model.name
  sku: {
    name: 'Standard'
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.name
      version: model.version
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

output openAIEnpoint string = account.properties.endpoint
output resource ResourceInfo = { id: account.id, name: account.name }
