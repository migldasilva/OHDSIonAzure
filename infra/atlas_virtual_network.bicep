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
        }
      }
      {
        name: 'WebAppOutbound'
        properties: {
          addressPrefix: subnetAddressPrefixes[1]
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

resource privateDNSZonePostgres 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
}

resource privateDNSZoneAzurewebsites 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

// Add a DNS A record for the PSQL Flexible Server
resource privateDNSZoneRecordA 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDNSZonePostgres
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

resource privateDNSZonePostgresLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZonePostgres
  name: 'private-link-postgres-${suffix}'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDNSZoneAzurewebsitesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDNSZoneAzurewebsites
  name: 'private-link-websites-${suffix}'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

output privateDNSZonePostgresID string = privateDNSZonePostgres.id
output privateDNSZonePostgresName string = privateDNSZonePostgres.name
output privateDNSZoneAzurewebsitesID string = privateDNSZoneAzurewebsites.id
output postgresVirtualSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'PostgreSQL')
output webAppVirtualSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'WebApp')
output webAppOutboundVirtualSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'WebAppOutbound')
output virtualNetworkId string = virtualNetwork.id
