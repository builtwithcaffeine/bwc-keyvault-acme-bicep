/*
  Example parameter file for Microsoft Graph OAuth2 Permission Grants Module
  
  This file demonstrates different scenarios for granting OAuth2 permissions to applications.
  OAuth2 permission grants represent the authorization given to a client application to access
  a specific resource on behalf of users (delegated permissions).
  
  To find these values:
  - Client ID: The object ID of your application's service principal
  - Resource ID: The object ID of the API's service principal (e.g., Microsoft Graph)
  - Principal ID: User object ID (only needed for user-specific consent)
  - Scope: Space-separated list of delegated permission scopes
  
  Usage:
  az deployment group create \
    --resource-group myResourceGroup \
    --template-file main.bicep \
    --parameters @parameters.example.bicepparam
*/

using 'main.bicep'

// ========== SCENARIO 1: ORGANIZATION-WIDE MICROSOFT GRAPH ACCESS ==========
// Grant Microsoft Graph permissions for all users in the organization

// Your application's service principal object ID
param clientId = '11111111-1111-1111-1111-111111111111'

// Grant permissions for all users in the organization
param consentType = 'AllPrincipals'

// Microsoft Graph service principal ID (constant for all Azure AD tenants)
param resourceId = '00000003-0000-0000-c000-000000000000'

// Space-separated list of Microsoft Graph delegated permission scopes
param scope = 'User.Read Directory.Read.All Group.Read.All'

// No principalId needed for AllPrincipals consent type
// param principalId = ''  // Leave empty or commented out

/*
  ========== OTHER COMMON SCENARIOS ==========
  
  SCENARIO 2: USER-SPECIFIC CONSENT
  // Grant permissions for a specific user only
  param clientId = '11111111-1111-1111-1111-111111111111'
  param consentType = 'Principal'
  param principalId = '22222222-2222-2222-2222-222222222222'  // Specific user object ID
  param resourceId = '00000003-0000-0000-c000-000000000000'   // Microsoft Graph
  param scope = 'User.Read Calendars.Read Mail.Read'
  
  SCENARIO 3: SHAREPOINT ONLINE ACCESS
  // Grant SharePoint Online permissions
  param clientId = '11111111-1111-1111-1111-111111111111'
  param consentType = 'AllPrincipals'
  param resourceId = '00000003-0000-0ff1-ce00-000000000000'   // SharePoint Online service principal
  param scope = 'Sites.Read.All Files.Read.All'
  
  SCENARIO 4: EXCHANGE ONLINE ACCESS
  // Grant Exchange Online permissions
  param clientId = '11111111-1111-1111-1111-111111111111'
  param consentType = 'AllPrincipals'
  param resourceId = '00000002-0000-0ff1-ce00-000000000000'   // Exchange Online service principal
  param scope = 'Mail.Read Calendars.Read'
  
  SCENARIO 5: CUSTOM API ACCESS
  // Grant permissions to your custom API
  param clientId = '11111111-1111-1111-1111-111111111111'
  param consentType = 'AllPrincipals'
  param resourceId = '33333333-3333-3333-3333-333333333333'   // Your API's service principal
  param scope = 'api://your-api/Read api://your-api/Write'
  
  SCENARIO 6: BASIC OPENID CONNECT
  // Grant basic OpenID Connect permissions
  param clientId = '11111111-1111-1111-1111-111111111111'
  param consentType = 'AllPrincipals'
  param resourceId = '00000003-0000-0000-c000-000000000000'   // Microsoft Graph
  param scope = 'openid profile email'
  
  COMMON RESOURCE SERVICE PRINCIPAL IDs:
  - Microsoft Graph: 00000003-0000-0000-c000-000000000000
  - SharePoint Online: 00000003-0000-0ff1-ce00-000000000000
  - Exchange Online: 00000002-0000-0ff1-ce00-000000000000
  - Azure Active Directory Graph (deprecated): 00000002-0000-0000-c000-000000000000
  
  COMMON MICROSOFT GRAPH DELEGATED PERMISSIONS:
  - User.Read: Read user profile
  - User.ReadBasic.All: Read all users' basic profiles
  - Directory.Read.All: Read directory data
  - Group.Read.All: Read all groups
  - Calendars.Read: Read user calendars
  - Mail.Read: Read user mail
  - Files.Read: Read user files
  - Sites.Read.All: Read items in all site collections
  
  CONSENT TYPE OPTIONS:
  - AllPrincipals: Grants consent for all users in the organization
  - Principal: Grants consent for a specific user (requires principalId)
  
  NOTE: Replace all sample GUIDs with your actual values from Azure AD
*/
