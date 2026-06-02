using 'main.bicep'

// ========== USER REFERENCE EXAMPLES ==========
// These examples demonstrate different patterns for referencing existing users in Azure AD

// ========== EXAMPLE 1: BASIC USER REFERENCE ==========
// Simple user reference by UPN - ideal for single user lookups
param userPrincipalName = 'john.doe@contoso.com'

// ========== EXAMPLE 2: EXECUTIVE USER ==========
// Reference a C-level executive for leadership team assignments
// param userPrincipalName = 'ceo@contoso.com'

// ========== EXAMPLE 3: SERVICE ACCOUNT ==========
// Reference a service account or non-human identity
// param userPrincipalName = 'service-account@contoso.com'

// ========== EXAMPLE 4: EXTERNAL PARTNER ==========
// Reference an external guest user (note the guest domain format)
// param userPrincipalName = 'partner_contoso.com#EXT#@contoso.onmicrosoft.com'

// ========== EXAMPLE 5: ADMIN USER ==========
// Reference a user with administrative privileges
// param userPrincipalName = 'admin@contoso.com'

// ========== EXAMPLE 6: DEPARTMENT LEAD ==========
// Reference a department or team lead
// param userPrincipalName = 'it-manager@contoso.com'

// ========== EXAMPLE 7: SHARED MAILBOX USER ==========
// Reference a user associated with a shared mailbox
// param userPrincipalName = 'support@contoso.com'

// ========== EXAMPLE 8: PROJECT MANAGER ==========
// Reference a project manager for project-specific access
// param userPrincipalName = 'project.manager@contoso.com'

// ========== EXAMPLE 9: BREAKGLASS ACCOUNT ==========
// Reference an emergency access account (use with caution)
// param userPrincipalName = 'emergency-access@contoso.com'

// ========== EXAMPLE 10: CONTRACTOR USER ==========
// Reference a contractor or temporary worker
// param userPrincipalName = 'contractor.smith@contoso.com'

// ========== USAGE NOTES ==========
/*
This module is designed for REFERENCING EXISTING USERS only.
It does not create new users - it retrieves information about users that already exist in Azure AD.

Common use cases:
- Getting user IDs for role assignments
- Retrieving user information for application permissions
- Validating user existence before granting access
- Building user lists for group management
- Fetching user details for reporting and auditing

Required format: UPN (User Principal Name) must be a valid email format
Guest users typically follow the pattern: originalEmail_domain.com#EXT#@tenant.onmicrosoft.com

For team or bulk operations, consider using arrays in your calling template:
var teamMembers = [
  'user1@contoso.com'
  'user2@contoso.com'
  'user3@contoso.com'
]
*/
