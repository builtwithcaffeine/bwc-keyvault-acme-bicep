using 'main.bicep'

// ========== BASIC APPLICATION CONFIGURATION ==========

// Required parameters
param displayName = 'Contoso Enterprise Application'
param appName = 'contoso-enterprise-app'

// Optional basic configuration
param appDescription = 'Enterprise application demonstrating comprehensive Microsoft Graph application configuration with security best practices'
param signInAudience = 'AzureADMyOrg'

// ========== WEB APPLICATION CONFIGURATION ==========

// Web redirect URIs for traditional web applications
param webRedirectUris = [
  'https://contoso-app.azurewebsites.net/signin-oidc'
  'https://contoso-app.azurewebsites.net/auth/callback'
  'https://contoso-app-staging.azurewebsites.net/signin-oidc'
  'https://localhost:5001/signin-oidc'  // Development
  'https://localhost:7001/signin-oidc'  // Development SSL
]

// Web application URLs
param homePageUrl = 'https://contoso-app.azurewebsites.net'
param logoutUrl = 'https://contoso-app.azurewebsites.net/signout-oidc'

// ========== SPA APPLICATION CONFIGURATION ==========

// Single Page Application redirect URIs (React, Angular, Vue, etc.)
param spaRedirectUris = [
  'https://contoso-spa.azurewebsites.net/auth/callback'
  'https://contoso-spa.azurewebsites.net/silent-renew'
  'https://contoso-spa-staging.azurewebsites.net/auth/callback'
  'http://localhost:3000/auth/callback'   // React default
  'http://localhost:4200/auth/callback'   // Angular default
  'http://localhost:8080/auth/callback'   // Vue default
]

// ========== MOBILE/DESKTOP APPLICATION CONFIGURATION ==========

// Public client redirect URIs for mobile and desktop applications
param publicClientRedirectUris = [
  'msauth.com.contoso.enterpriseapp://auth'           // iOS
  'msauth://com.contoso.enterpriseapp/AbCdEfGhIjK'   // Android
  'ms-app://s-1-15-2-1234567890-1234567890-1234567890-1234567890-1234567890-1234567890-1234567890/' // UWP
  'https://login.microsoftonline.com/common/oauth2/nativeclient' // MSAL fallback
  'http://localhost:8080'  // Development
]

// Enable fallback for public clients (important for mobile apps)
param isFallbackPublicClient = true

// Enable device authentication for scenarios like IoT or limited input devices
param isDeviceOnlyAuthSupported = false

// ========== API CONFIGURATION ==========

// Application ID URI (used when this app exposes an API)
param identifierUris = [
  'api://contoso-enterprise-app'
]

// OAuth2 permission scopes that this application exposes
param oauth2PermissionScopes = [
  {
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  // Generate unique GUID
    adminConsentDescription: 'Allows the application to read user profile data on behalf of the signed-in user'
    adminConsentDisplayName: 'Read user profiles'
    userConsentDescription: 'Allows the app to read your profile information'
    userConsentDisplayName: 'Read your profile'
    value: 'User.Read'
    type: 'User'
    isEnabled: true
  }
  {
    id: 'b2c3d4e5-f6a7-8901-bcde-f23456789012'  // Generate unique GUID
    adminConsentDescription: 'Allows the application to access company directory data'
    adminConsentDisplayName: 'Access directory data'
    userConsentDescription: 'Allows the app to access company directory information on your behalf'
    userConsentDisplayName: 'Access directory data'
    value: 'Directory.Access'
    type: 'Admin'
    isEnabled: true
  }
]

// Application roles for role-based access control
param appRoles = [
  {
    id: 'c3d4e5f6-a7b8-9012-cdef-345678901234'  // Generate unique GUID
    displayName: 'Administrator'
    description: 'Full administrative access to the application'
    value: 'App.Admin'
    allowedMemberTypes: ['User']
    isEnabled: true
  }
  {
    id: 'd4e5f6a7-b8c9-0123-defa-456789012345'  // Generate unique GUID
    displayName: 'User'
    description: 'Standard user access to the application'
    value: 'App.User'
    allowedMemberTypes: ['User', 'Application']
    isEnabled: true
  }
  {
    id: 'e5f6a7b8-c9d0-1234-efab-567890123456'  // Generate unique GUID
    displayName: 'Reader'
    description: 'Read-only access to application data'
    value: 'App.Reader'
    allowedMemberTypes: ['User', 'Application']
    isEnabled: true
  }
]

// ========== TOKEN CONFIGURATION ==========

// Implicit grant settings (use sparingly, prefer authorization code flow)
param enableIdTokenIssuance = true
param enableAccessTokenIssuance = false

// Access token version (v2 is recommended for new applications)
param requestedAccessTokenVersion = 2

// Group membership claims in tokens
param groupMembershipClaims = 'SecurityGroup'

// Advanced API settings
param acceptMappedClaims = false

// ========== API PERMISSIONS ==========

// Required resource access (API permissions)
param requiredResourceAccess = [
  {
    resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
    resourceAccess: [
      {
        id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read (delegated)
        type: 'Scope'
      }
      {
        id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All (delegated)
        type: 'Scope'
      }
      {
        id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182' // offline_access (delegated)
        type: 'Scope'
      }
      {
        id: '62a82d76-70ea-41e2-9197-370581804d09' // Group.ReadWrite.All (delegated)
        type: 'Scope'
      }
      {
        id: '5b567255-7703-4780-807c-7be8301ae99b' // Group.Read.All (application)
        type: 'Role'
      }
      {
        id: 'df021288-bdef-4463-88db-98f22de89214' // User.Read.All (application)
        type: 'Role'
      }
    ]
  }
  {
    resourceAppId: '797f4846-ba00-4fd7-ba43-dac1f8f63013' // Azure Service Management API
    resourceAccess: [
      {
        id: '41094075-9dad-400e-a0bd-54e686782033' // user_impersonation
        type: 'Scope'
      }
    ]
  }
]

// Pre-authorized applications (for trusted first-party scenarios)
param preAuthorizedApplications = [
  {
    appId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  // Trusted client application ID
    delegatedPermissionIds: [
      'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  // Matches scope ID from oauth2PermissionScopes
    ]
  }
]

// ========== OPTIONAL CLAIMS CONFIGURATION ==========

// Optional claims to include in tokens
param optionalClaims = {
  accessToken: [
    {
      name: 'groups'
      essential: false
    }
    {
      name: 'preferred_username'
      essential: false
    }
    {
      name: 'email'
      essential: false
    }
  ]
  idToken: [
    {
      name: 'groups'
      essential: false
    }
    {
      name: 'email'
      essential: false
    }
    {
      name: 'family_name'
      essential: false
    }
    {
      name: 'given_name'
      essential: false
    }
  ]
  saml2Token: [
    {
      name: 'groups'
      essential: false
    }
  ]
}

// ========== APPLICATION INFORMATION ==========

// Application information URLs for compliance and user information
param applicationInfo = {
  marketingUrl: 'https://contoso.com/products/enterprise-app'
  privacyStatementUrl: 'https://contoso.com/privacy'
  supportUrl: 'https://support.contoso.com/enterprise-app'
  termsOfServiceUrl: 'https://contoso.com/terms-of-service'
}

// ========== SECURITY AND COMPLIANCE ==========

// Authentication behaviors for enhanced security
param authenticationBehaviors = {
  removeUnverifiedEmailClaim: true
  requireClientServicePrincipal: true
}

// Parental controls (for consumer applications)
param parentalControlSettings = {
  countriesBlockedForMinors: ['US', 'CA']  // Example countries
  legalAgeGroupRule: 'RequireConsentForPrivacyServices'
}

// ========== CERTIFICATES AND SECRETS ==========

// Key credentials (certificates) - Note: Actual certificates should be managed separately
param keyCredentials = [
  // Example structure - actual certificates should be added through secure deployment processes
  // {
  //   type: 'AsymmetricX509Cert'
  //   usage: 'Verify'
  //   key: '...' // Base64 encoded certificate
  //   displayName: 'Main Certificate'
  // }
]

// Password credentials (client secrets) - Note: Secrets should be managed through secure processes
param passwordCredentials = [
  // Example structure - actual secrets should be added through secure deployment processes
  // {
  //   displayName: 'Main Secret'
  //   hint: 'mai'
  //   secretText: '...' // Should be retrieved from Key Vault or secure parameter
  // }
]

// ========== METADATA AND MANAGEMENT ==========

// Application tags for organization and management
param tags = [
  'environment:production'
  'team:platform'
  'cost-center:engineering'
  'compliance:sox'
  'security-review:approved'
  'deployment-method:bicep'
]

// Administrative notes
param notes = 'Enterprise application with comprehensive security configuration. Supports web, SPA, and mobile platforms. Includes custom API scopes and application roles for fine-grained access control.'

// Service management reference for tracking
param serviceManagementReference = 'SNOW-REQ-12345'

// Application owners (should be actual user object IDs)
param ownerIds = [
  // '12345678-1234-1234-1234-123456789012'  // Platform Team Lead
  // '23456789-2345-2345-2345-234567890123'  // Security Team Lead
]

// ========== ADVANCED CONFIGURATION ==========

// Native authentication APIs (for advanced scenarios)
param nativeAuthenticationApisEnabled = 'none'

// Service principal lock configuration
param servicePrincipalLockConfiguration = {
  isEnabled: true
  allProperties: false
  credentialsWithUsageVerify: false
  credentialsWithUsageSign: false
  tokenEncryptionKeyId: false
}

// SAML metadata URL (for SAML federation scenarios)
param samlMetadataUrl = ''

// Token encryption key ID (for sensitive data scenarios)
param tokenEncryptionKeyId = ''
