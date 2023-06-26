param location string
param suffix string
@description('The address space for this Virtual Network.')
param addressPrefix string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${suffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'WebApp'
        properties: {
          addressPrefix: '192.168.49.0/27'
          delegations: [
            {
              name: 'WebAppDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: 'WebAppOutbound'
        properties: {
          addressPrefix: '192.168.49.32/27'          
        }
      }
      {
        name: 'PostgreSQL'
        properties: {
          addressPrefix: '192.168.49.64/27'
          delegations: [
            {
              name: 'PostgreSQLDelegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'private.postgres.database.azure.com'
  location: 'global'
}

resource privateDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZone
  name: 'private-link-psql-${suffix}'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

output privateDNSZoneID string = privateDNSZone.id
output postgresVirtualSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'PostgreSQL')
output virtualNetworkId string = virtualNetwork.id
