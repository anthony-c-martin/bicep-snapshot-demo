using './handler/main.bicep'

param namePrefix = 'cp'
param containerAppPrefix = 'cpca'
param nameSuffix = 'prod'
param envName = 'prod'

param registryName = 'myregistry'
param openAiLocation = 'westus2'
param backendImage = {
  name: 'copilot-handler'
  registry: registryName
  tag: '0.0.1'
}
param dataImage = {
  name: 'copilot-dataloader'
  registry: registryName
  tag: '0.0.1'
}

param cosmosDbIngress = {
  allowAllAzureServiceIpAddresses: true
  allowedIps: [
    '192.168.0.1'
  ]
}

param handlerConfig = {
  authorizedAudiences: [
    '25566d5c-e720-4c1d-bd6f-0031239a89d1'
  ]
  authorizedAppIds: [
    '6afa3943-03b1-459b-8128-25473180430d'
  ]
}
