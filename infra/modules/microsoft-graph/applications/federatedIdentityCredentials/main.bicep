// Microsoft Graph Federated Identity Credentials Module
// Creates federated identity credentials for an Azure AD application using Microsoft Graph Bicep

metadata name = 'Microsoft Graph Federated Identity Credentials'
metadata description = 'Creates and configures federated identity credentials for Azure AD applications'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. The application unique name (from Microsoft Graph applications module)')
param applicationId string

@description('Required. Name of the federated identity credential')
param name string

@description('Required. The issuer of the external identity provider')
@metadata({
  examples: [
    'https://token.actions.githubusercontent.com'
    'https://vstoken.dev.azure.com/{organization}'
    'https://accounts.google.com'
    'arn:aws:iam::{account}:oidc-provider/token.actions.githubusercontent.com'
  ]
})
param issuer string

@description('Required. The subject claim from the incoming token')
@metadata({
  examples: [
    'repo:owner/repository:ref:refs/heads/main'
    'repo:owner/repository:environment:production'
    'repo:owner/repository:pull_request'
  ]
})
param subject string

@description('Required. The audiences that can appear in the external token')
@minLength(1)
param audiences array

@description('Optional. Description of the federated identity credential')
param credentialDescription string = ''

// ========== VARIABLES ==========

// Ensure we have valid audiences - default to the standard token exchange audience if empty
var validatedAudiences = length(audiences) > 0 ? audiences : ['api://AzureADTokenExchange']

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph Federated Identity Credential')
resource federatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${applicationId}/${name}'
  audiences: validatedAudiences
  description: !empty(credentialDescription) ? credentialDescription : null
  issuer: issuer
  subject: subject
}

// ========== OUTPUTS ==========

@description('The resource ID of the federated identity credential')
output resourceId string = federatedIdentityCredential.id

@description('The name of the federated identity credential')
output name string = name

@description('The issuer of the federated identity credential')
output issuer string = issuer

@description('The subject of the federated identity credential')
output subject string = subject

@description('The audiences of the federated identity credential')
output audiences array = validatedAudiences

@description('The description of the federated identity credential')
output credentialDescription string = !empty(credentialDescription) ? credentialDescription : ''
