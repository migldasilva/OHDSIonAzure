param location string
param suffix string
@description('The address space for this Virtual Network.')
param addressPrefix string

// We calculate the subnets from the given address prefix
var subnetAddressPrefixes = [for i in range(0, 8): cidrSubnet(addressPrefix, 27, i)]

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
          addressPrefix: subnetAddressPrefixes[0]
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
          addressPrefix: subnetAddressPrefixes[1]
        }
      }
      {
        name: 'PostgreSQL'
        properties: {
          addressPrefix: subnetAddressPrefixes[2]
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

// Add a DNS A record for the PSQL Flexible Server
resource privateDNSZoneRecordA 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDNSZone
  name: 'psql-${suffix}'
  properties: {
    ttl: 30
    aRecords: [
      {
        // We assigne a static private IP address
        ipv4Address: cidrHost(subnetAddressPrefixes[2], 4)
      }
    ]
  }
}

resource privateDNSZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZone
  name: 'private-link-${suffix}'
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
output privateDNSZoneName string = privateDNSZone.name
