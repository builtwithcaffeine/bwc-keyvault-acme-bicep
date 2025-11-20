// Microsoft Graph Application Module
// Creates an Azure AD application registration using Microsoft Graph Bicep

metadata name = 'Microsoft Graph Application'
metadata description = 'Creates and configures an Azure AD application registration'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. Display name for the application')
param displayName string

@description('Required. Application Name (unique identifier)')
param appName string

@description('Optional. Description of the application')
param appDescription string = ''

@description('Optional. Sign-in audience for the application')
@allowed([
  'AzureADMyOrg'
  'AzureADMultipleOrgs'
  'AzureADandPersonalMicrosoftAccount'
  'PersonalMicrosoftAccount'
])
param signInAudience string = 'AzureADMyOrg'

@description('Optional. Whether this is a fallback public client (for mobile/desktop apps)')
param isFallbackPublicClient bool = false

@description('Optional. Whether device-only authentication is supported')
param isDeviceOnlyAuthSupported bool = false

@description('Optional. Web redirect URIs')
param webRedirectUris array = []

@description('Optional. SPA redirect URIs')
param spaRedirectUris array = []

@description('Optional. Public client redirect URIs (mobile/desktop)')
param publicClientRedirectUris array = []

@description('Optional. Homepage URL for the application')
param homePageUrl string = ''

@description('Optional. Logout URL for the application')
param logoutUrl string = ''

@description('Optional. Default redirect URI')
param defaultRedirectUri string = ''

@description('Optional. Application identifier URIs')
param identifierUris array = []

@description('Optional. Required resource access (API permissions)')
param requiredResourceAccess array = []

@description('Optional. App roles to be defined for the application')
param appRoles array = []

@description('Optional. OAuth2 permission scopes to expose')
param oauth2PermissionScopes array = []

@description('Optional. Pre-authorized applications')
param preAuthorizedApplications array = []

@description('Optional. Known client applications')
param knownClientApplications array = []

@description('Optional. Accept mapped claims in API')
param acceptMappedClaims bool = false

@description('Optional. Requested access token version')
@allowed([1, 2])
param requestedAccessTokenVersion int = 2

@description('Optional. Enable implicit grant for access tokens')
param enableAccessTokenIssuance bool = false

@description('Optional. Enable implicit grant for ID tokens')
param enableIdTokenIssuance bool = false

@description('Optional. Group membership claims configuration')
@allowed([
  'None'
  'SecurityGroup'
  'DirectoryRole'
  'ApplicationGroup'
  'All'
])
param groupMembershipClaims string = 'None'

@description('Optional. Optional claims configuration')
param optionalClaims object = {}

@description('Optional. Tags to apply to the application')
param tags array = []

@description('Optional. Notes for the application')
param notes string = ''

@description('Optional. Application info URLs')
param applicationInfo object = {}

@description('Optional. Key credentials (certificates)')
param keyCredentials array = []

@description('Optional. Password credentials (client secrets)')
param passwordCredentials array = []

@description('Optional. Owner object IDs')
param ownerIds array = []

@description('Optional. Add-ins configuration')
param addIns array = []

@description('Optional. Authentication behaviors')
param authenticationBehaviors object = {}

@description('Optional. Parental control settings')
param parentalControlSettings object = {}

@description('Optional. Request signature verification settings')
param requestSignatureVerification object = {}

@description('Optional. Service management reference')
param serviceManagementReference string = ''

@description('Optional. Service principal lock configuration')
param servicePrincipalLockConfiguration object = {}

@description('Optional. Token encryption key ID')
param tokenEncryptionKeyId string = ''

@description('Optional. SAML metadata URL')
param samlMetadataUrl string = ''

@description('Optional. Native authentication APIs enabled setting')
@allowed([
  'none'
  'all'
])
param nativeAuthenticationApisEnabled string = 'none'

@description('Optional. Disabled by Microsoft status')
param disabledByMicrosoftStatus string = ''

@description('Optional. Web redirect URI settings with indices')
param redirectUriSettings array = []

// ========== VARIABLES ==========

// Configure owners relationship if provided
var ownersConfig = !empty(ownerIds) ? {
  relationships: ownerIds
  relationshipSemantics: 'append'
} : null

// Web configuration
var webConfig = (!empty(webRedirectUris) || !empty(homePageUrl) || !empty(logoutUrl) || enableAccessTokenIssuance || enableIdTokenIssuance || !empty(redirectUriSettings)) ? {
  homePageUrl: !empty(homePageUrl) ? homePageUrl : null
  logoutUrl: !empty(logoutUrl) ? logoutUrl : null
  redirectUris: webRedirectUris
  implicitGrantSettings: (enableAccessTokenIssuance || enableIdTokenIssuance) ? {
    enableAccessTokenIssuance: enableAccessTokenIssuance
    enableIdTokenIssuance: enableIdTokenIssuance
  } : null
  redirectUriSettings: redirectUriSettings
} : null

// SPA configuration
var spaConfig = !empty(spaRedirectUris) ? {
  redirectUris: spaRedirectUris
} : null

// Public client configuration
var publicClientConfig = !empty(publicClientRedirectUris) ? {
  redirectUris: publicClientRedirectUris
} : null

// API configuration
var apiConfig = (!empty(oauth2PermissionScopes) || !empty(preAuthorizedApplications) || !empty(knownClientApplications) || acceptMappedClaims || requestedAccessTokenVersion != 2) ? {
  acceptMappedClaims: acceptMappedClaims
  knownClientApplications: knownClientApplications
  oauth2PermissionScopes: oauth2PermissionScopes
  preAuthorizedApplications: preAuthorizedApplications
  requestedAccessTokenVersion: requestedAccessTokenVersion
} : null

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph Application')
resource application 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appName
  displayName: displayName
  description: !empty(appDescription) ? appDescription : null
  signInAudience: signInAudience
  isFallbackPublicClient: isFallbackPublicClient
  isDeviceOnlyAuthSupported: isDeviceOnlyAuthSupported
  defaultRedirectUri: !empty(defaultRedirectUri) ? defaultRedirectUri : null
  identifierUris: identifierUris
  requiredResourceAccess: requiredResourceAccess
  appRoles: appRoles
  groupMembershipClaims: groupMembershipClaims != 'None' ? groupMembershipClaims : null
  tags: tags
  notes: !empty(notes) ? notes : null
  info: !empty(applicationInfo) ? applicationInfo : null
  keyCredentials: keyCredentials
  passwordCredentials: passwordCredentials
  addIns: addIns
  authenticationBehaviors: !empty(authenticationBehaviors) ? authenticationBehaviors : null
  parentalControlSettings: !empty(parentalControlSettings) ? parentalControlSettings : null
  requestSignatureVerification: !empty(requestSignatureVerification) ? requestSignatureVerification : null
  serviceManagementReference: !empty(serviceManagementReference) ? serviceManagementReference : null
  servicePrincipalLockConfiguration: !empty(servicePrincipalLockConfiguration) ? servicePrincipalLockConfiguration : null
  tokenEncryptionKeyId: !empty(tokenEncryptionKeyId) ? tokenEncryptionKeyId : null
  samlMetadataUrl: !empty(samlMetadataUrl) ? samlMetadataUrl : null
  nativeAuthenticationApisEnabled: nativeAuthenticationApisEnabled != 'none' ? nativeAuthenticationApisEnabled : null
  disabledByMicrosoftStatus: !empty(disabledByMicrosoftStatus) ? disabledByMicrosoftStatus : null
  web: webConfig
  spa: spaConfig
  publicClient: publicClientConfig
  api: apiConfig
  optionalClaims: !empty(optionalClaims) ? optionalClaims : null
  owners: ownersConfig
}

// ========== OUTPUTS ==========

@description('The resource ID of the application')
output resourceId string = application.id

@description('The application (client) ID')
output applicationId string = application.appId

@description('The object ID of the application')
output objectId string = application.id

@description('The display name of the application')
output displayName string = application.displayName

@description('The unique name of the application')
output uniqueName string = application.uniqueName

@description('The sign-in audience of the application')
output signInAudience string = application.signInAudience

@description('Whether this is a fallback public client')
output isFallbackPublicClient bool = application.isFallbackPublicClient

@description('Whether device-only authentication is supported')
output isDeviceOnlyAuthSupported bool = application.isDeviceOnlyAuthSupported

@description('The application identifier URIs')
output identifierUris array = application.identifierUris

@description('The default redirect URI')
output defaultRedirectUri string = application.defaultRedirectUri != null ? application.defaultRedirectUri : ''

@description('The group membership claims setting')
output groupMembershipClaims string = application.groupMembershipClaims != null ? application.groupMembershipClaims : 'None'

@description('Application tags')
output tags array = application.tags

@description('Application description')
output description string = application.description != null ? application.description : ''

@description('Web configuration including redirect URIs and homepage')
output webConfiguration object = application.web != null ? application.web : {}

@description('SPA configuration including redirect URIs')
output spaConfiguration object = application.spa != null ? application.spa : {}

@description('Public client configuration including redirect URIs')
output publicClientConfiguration object = application.publicClient != null ? application.publicClient : {}

@description('API configuration including OAuth2 permissions and pre-authorized apps')
output apiConfiguration object = application.api != null ? application.api : {}

@description('Application password credentials configuration')
output applicationCredentials array = application.passwordCredentials

@description('Number of password credentials configured')
output credentialCount int = length(application.passwordCredentials)
