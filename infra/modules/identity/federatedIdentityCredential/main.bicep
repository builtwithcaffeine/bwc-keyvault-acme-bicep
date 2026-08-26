metadata name = 'User Assigned Identity Federated Credential'
metadata description = 'This module deploys a federated identity credential on an existing user-assigned managed identity, enabling OIDC-based authentication (e.g. GitHub Actions) without a client secret.'

@description('Required. The name of the existing user-assigned managed identity.')
param userAssignedIdentityName string

@description('Required. The name of the federated identity credential.')
param name string

@description('Required. The URL of the token issuer, matching the issuer claim of the external identity provider tokens.')
param issuer string

@description('Required. The subject identifier of the external identity, matching the subject claim of the external identity provider tokens.')
param subject string

@description('Optional. The audiences that can appear in the issued token.')
param audiences array = ['api://AzureADTokenExchange']

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: userAssignedIdentityName
}

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  name: name
  parent: userAssignedIdentity
  properties: {
    issuer: issuer
    subject: subject
    audiences: audiences
  }
}

@description('The name of the federated identity credential.')
output name string = federatedCredential.name

@description('The resource ID of the federated identity credential.')
output resourceId string = federatedCredential.id
