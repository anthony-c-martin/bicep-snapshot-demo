@export()
type UserAssignedIdentity = {
  resourceId: string
  principalId: string
  clientId: string
  tenantId: string
}

@export()
type ContainerImage = {
  registry: string
  name: string
  tag: string
}

@export()
type ResourceInfo = {
  id: string
  name: string
}

@export()
type CosmosDbIngress = {
  @description('Array of allowed ip addresses and ranges')
  allowedIps: string[]
  @description('If set to true, enables the (Allow public access from any Azure service within Azure to this server) firewall rule')
  allowAllAzureServiceIpAddresses: bool
}

@export()
type CopilotHandlerConfig = {
  @description('Acceptable audience claims that are authorized to call the handler API')
  authorizedAudiences: string[]
  @description('Entra ID applications that are authorized to call the handler API')
  authorizedAppIds: string[]
}
