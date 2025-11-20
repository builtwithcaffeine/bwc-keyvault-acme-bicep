/*
  Example parameter file for Microsoft Graph App Role Assignment Module
  
  This file demonstrates different scenarios for assigning app roles to various principal types.
  Replace the sample values with your actual Azure AD object IDs and app role IDs.
  
  To find these values:
  - App Role IDs: Check the application manifest in Azure portal
  - Principal IDs: Use Azure AD users, groups, or service principals object IDs
  - Resource ID: The service principal object ID that defines the app roles
  
  Usage:
  az deployment group create \
    --resource-group myResourceGroup \
    --template-file main.bicep \
    --parameters @parameters.example.bicepparam
*/

using 'main.bicep'

// ========== SCENARIO 1: SERVICE PRINCIPAL API ACCESS ==========
// Assign API read permission to a service principal (common for application-to-application access)

// The app role ID for API read access (replace with actual role ID from your application)
param appRoleId = '62e90394-69f5-4237-9190-012177145e10'

// The object ID of the service principal that needs access (your client application's service principal)
param principalId = '11111111-1111-1111-1111-111111111111'

// The object ID of the service principal that defines the app role (your API's service principal)
param resourceId = '22222222-2222-2222-2222-222222222222'

// Display name for the resource (for documentation and tracking)
param resourceDisplayName = 'Customer Management API'

// Principal type - ServicePrincipal for application-to-application access
param principalType = 'ServicePrincipal'

/*
  ========== OTHER COMMON SCENARIOS ==========
  
  SCENARIO 2: USER ACCESS
  // Assign role to a specific user
  param appRoleId = 'c79f8feb-a9db-4090-85f9-90d820caa0eb'    // API.Write role
  param principalId = '33333333-3333-3333-3333-333333333333'   // User object ID
  param resourceId = '22222222-2222-2222-2222-222222222222'    // API service principal
  param resourceDisplayName = 'Customer Management API'
  param principalType = 'User'
  
  SCENARIO 3: GROUP ACCESS
  // Assign role to a security group (all group members inherit the permission)
  param appRoleId = '2d05a661-f651-4d57-a595-489c91eda336'    // API.Admin role
  param principalId = '44444444-4444-4444-4444-444444444444'   // Security group object ID
  param resourceId = '22222222-2222-2222-2222-222222222222'    // API service principal
  param resourceDisplayName = 'Customer Management API'
  param principalType = 'Group'
  
  SCENARIO 4: MICROSOFT GRAPH PERMISSIONS
  // Assign Microsoft Graph permissions to a service principal
  param appRoleId = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'    // Directory.Read.All
  param principalId = '11111111-1111-1111-1111-111111111111'   // Your app's service principal
  param resourceId = '00000003-0000-0000-c000-000000000000'    // Microsoft Graph service principal (constant)
  param resourceDisplayName = 'Microsoft Graph'
  param principalType = 'ServicePrincipal'
  
  COMMON APP ROLE IDs:
  - Directory.Read.All: 7ab1d382-f21e-4acd-a863-ba3e13f7da61
  - Directory.ReadWrite.All: 19dbc75e-c2e2-444c-a770-ec69d8559fc7
  - User.Read.All: df021288-bdef-4463-88db-98f22de89214
  - User.ReadWrite.All: 741f803b-c850-494e-b5df-cde7c675a1ca
  - Application.Read.All: 9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30
  - Application.ReadWrite.All: 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9
  
  NOTE: Replace all sample GUIDs with your actual values from Azure AD
*/
