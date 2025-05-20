import { ResourceInfo } from '../../shared/types.bicep'

param namePrefix string
param location string
param nameSuffix string

var addressPrefix = '10.1.0.0/16'

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: '${namePrefix}-vnet-${nameSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }

  resource apimSubnet 'subnets' = {
    name: 'apim-subnet'
    properties: {
      addressPrefix: cidrSubnet(addressPrefix, 22, 0)
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }

  resource acaSubnet 'subnets' = {
    name: 'aca-subnet'
    properties: {
      addressPrefix: cidrSubnet(cidrSubnet(addressPrefix, 22, 1), 24, 0)
      networkSecurityGroup: {
        id: nsg.id
      }
      delegations: [
        {
          name: 'Microsoft.App.environments'
          properties: {
            serviceName: 'Microsoft.App/environments'
          }
        }
      ]
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${namePrefix}-nsg-${nameSuffix}'
  location: location

  // Do not add any rules with priority between 100-119.
  // See https://aka.ms/cainsgpolicy for info.

  resource inboundHttps 'securityRules' = {
    name: 'Inbound_HTTPS'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 200
      direction: 'Inbound'
    }
  }

  resource inboundManagement 'securityRules' = {
    name: 'Inbound_Management'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3443'
      sourceAddressPrefix: 'ApiManagement'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 210
      direction: 'Inbound'
    }
  }

  resource inboundLoadBalancer 'securityRules' = {
    name: 'Inbound_LoadBalancer'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '6390'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 220
      direction: 'Inbound'
    }
  }

  resource inboundTrafficManager 'securityRules' = {
    name: 'Inbound_AzureTrafficManager'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'AzureTrafficManager'
      destinationAddressPrefix: 'VirtualNetwork'
      access: 'Allow'
      priority: 230
      direction: 'Inbound'
    }
  }
}

output apimSubnet ResourceInfo = { id: vnet::apimSubnet.id, name: vnet::apimSubnet.name }
output acaSubnet ResourceInfo = { id: vnet::acaSubnet.id, name: vnet::acaSubnet.name }
