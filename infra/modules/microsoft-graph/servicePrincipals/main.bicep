// Microsoft Graph Service Principals Module
// Creates Azure AD service principals using Microsoft Graph Bicep

metadata name = 'Microsoft Graph Service Principals'
metadata description = 'Creates and configures Azure AD service principals'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. Application ID of the application to create service principal for')
param appId string

@description('Optional. Display name for the service principal')
param displayName string = ''

@description('Optional. Whether the service principal account is enabled')
param accountEnabled bool = true

@description('Optional. Whether app role assignment is required for this service principal')
param appRoleAssignmentRequired bool = false

@description('Optional. Alternative names for the service principal')
param alternativeNames array = []

@description('Optional. Homepage URL')
param homepage string = ''

@description('Optional. Login URL')
param loginUrl string = ''

@description('Optional. Logout URL')
param logoutUrl string = ''

@description('Optional. Reply URLs for the service principal')
param replyUrls array = []

@description('Optional. Service principal type')
param servicePrincipalType string = 'Application'

@description('Optional. Tags for the service principal')
param tags array = []

@description('Optional. Notes for the service principal')
param notes string = ''

@description('Optional. Notification email addresses')
param notificationEmailAddresses array = []

@description('Optional. Preferred single sign-on mode')
param preferredSingleSignOnMode string = ''

@description('Optional. App roles for the service principal')
param appRoles array = []

@description('Optional. OAuth2 permission scopes')
param oauth2PermissionScopes array = []

@description('Optional. Key credentials')
param keyCredentials array = []

@description('Optional. Password credentials')
param passwordCredentials array = []

@description('Optional. Owner object IDs')
param ownerIds array = []

@description('Optional. Application info URLs')
param info object = {}

@description('Optional. Add-ins for the service principal')
param addIns array = []

// Note: appDescription and appDisplayName are read-only properties and should not be included

@description('Optional. Custom security attributes')
param customSecurityAttributes object = {}

@description('Optional. Disabled by Microsoft status')
param disabledByMicrosoftStatus string = ''

@description('Optional. Preferred token signing key thumbprint')
param preferredTokenSigningKeyThumbprint string = ''

@description('Optional. SAML single sign-on settings')
param samlSingleSignOnSettings object = {}

// Note: Some properties like servicePrincipalNames may be read-only and auto-generated

@description('Optional. Token encryption key ID')
param tokenEncryptionKeyId string = ''

// ========== VARIABLES ==========

// Configure owners relationship if provided
var ownersConfig = !empty(ownerIds) ? {
  relationships: ownerIds
  relationshipSemantics: 'append'
} : null

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph Service Principal')
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: appId
  displayName: !empty(displayName) ? displayName : null
  accountEnabled: accountEnabled
  addIns: addIns
  alternativeNames: alternativeNames
  appRoleAssignmentRequired: appRoleAssignmentRequired
  appRoles: appRoles
  customSecurityAttributes: !empty(customSecurityAttributes) ? customSecurityAttributes : null
  disabledByMicrosoftStatus: !empty(disabledByMicrosoftStatus) ? disabledByMicrosoftStatus : null
  homepage: !empty(homepage) ? homepage : null
  info: !empty(info) ? info : null
  keyCredentials: keyCredentials
  loginUrl: !empty(loginUrl) ? loginUrl : null
  logoutUrl: !empty(logoutUrl) ? logoutUrl : null
  notes: !empty(notes) ? notes : null
  notificationEmailAddresses: notificationEmailAddresses
  oauth2PermissionScopes: oauth2PermissionScopes
  owners: ownersConfig
  passwordCredentials: passwordCredentials
  preferredSingleSignOnMode: !empty(preferredSingleSignOnMode) ? preferredSingleSignOnMode : null
  preferredTokenSigningKeyThumbprint: !empty(preferredTokenSigningKeyThumbprint) ? preferredTokenSigningKeyThumbprint : null
  replyUrls: replyUrls
  samlSingleSignOnSettings: !empty(samlSingleSignOnSettings) ? samlSingleSignOnSettings : null
  servicePrincipalType: servicePrincipalType
  tags: tags
  tokenEncryptionKeyId: !empty(tokenEncryptionKeyId) ? tokenEncryptionKeyId : null
}

// ========== OUTPUTS ==========

@description('The resource ID of the service principal')
output resourceId string = servicePrincipal.id

@description('The service principal ID (object ID)')
output servicePrincipalId string = servicePrincipal.id

@description('The application ID')
output appId string = servicePrincipal.appId

@description('The display name of the service principal')
output displayName string = servicePrincipal.displayName

@description('Whether the service principal account is enabled')
output accountEnabled bool = servicePrincipal.accountEnabled

@description('The service principal type')
output servicePrincipalType string = servicePrincipal.servicePrincipalType

@description('Whether app role assignment is required')
output appRoleAssignmentRequired bool = servicePrincipal.appRoleAssignmentRequired

@description('The service principal names')
output servicePrincipalNames array = servicePrincipal.servicePrincipalNames

@description('The preferred single sign-on mode')
output preferredSingleSignOnMode string = servicePrincipal.preferredSingleSignOnMode != null ? servicePrincipal.preferredSingleSignOnMode : ''
