// Microsoft Graph OAuth2 Permission Grants Module
// Creates OAuth2 permission grants for service principals using Microsoft Graph Bicep

metadata name = 'Microsoft Graph OAuth2 Permission Grants'
metadata description = 'Creates and configures OAuth2 permission grants for service principals'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. The unique identifier for the client service principal for the application which is authorized to act on behalf of a signed-in user when accessing an API')
param clientId string

@description('Required. Indicates if authorization is granted for the client application to impersonate all users or only a specific user')
@allowed([
  'AllPrincipals'
  'Principal'
])
param consentType string

@description('Optional. The unique identifier for the user on whose behalf the client is authorized to access the resource when consentType is Principal. If consentType is AllPrincipals this value is null')
param principalId string = ''

@description('Required. The unique identifier for the resource service principal for which the access is authorized')
param resourceId string

@description('Optional. A space-separated list of the claim values for delegated permissions which should be included in access tokens for the resource application')
param scope string = ''

// ========== VARIABLES ==========

// Set principalId to null if empty or if consentType is AllPrincipals
var principalIdValue = (consentType == 'AllPrincipals' || empty(principalId)) ? null : principalId

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph OAuth2 Permission Grant')
resource oauth2PermissionGrant 'Microsoft.Graph/oauth2PermissionGrants@v1.0' = {
  clientId: clientId
  consentType: consentType
  principalId: principalIdValue
  resourceId: resourceId
  scope: !empty(scope) ? scope : null
}

// ========== OUTPUTS ==========

@description('The resource ID of the OAuth2 permission grant')
output resourceId string = oauth2PermissionGrant.id

@description('The OAuth2 permission grant ID')
output oauth2PermissionGrantId string = oauth2PermissionGrant.id

@description('The client service principal ID')
output clientId string = oauth2PermissionGrant.clientId

@description('The consent type')
output consentType string = oauth2PermissionGrant.consentType

@description('The principal ID (if applicable)')
output principalId string = oauth2PermissionGrant.principalId != null ? oauth2PermissionGrant.principalId : ''

@description('The resource service principal ID')
output resourceServicePrincipalId string = oauth2PermissionGrant.resourceId

@description('The granted scopes')
output scope string = oauth2PermissionGrant.scope != null ? oauth2PermissionGrant.scope : ''
