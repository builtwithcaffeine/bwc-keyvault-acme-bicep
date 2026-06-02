using 'main.bicep'

// ========== REQUIRED PARAMETERS ==========

// Display name for the group (unique within organization)
param displayName = 'Contoso IT Security Team'

// Unique group name for Microsoft Graph resource
param groupName = 'contoso-it-security-team'

// Mail nickname for the group (must be unique)
param mailNickname = 'contoso-it-security'

// ========== BASIC CONFIGURATION ==========

// Group description
param groupDescription = 'Security group for IT team members with administrative access to corporate resources'

// Group type settings
param securityEnabled = true
param mailEnabled = false

// Group visibility and access
param visibility = 'Private'

// ========== SECURITY AND COMPLIANCE ==========

// Group classification for compliance
param classification = 'High'

// Role assignment capability (requires Azure AD Premium P1)
param isAssignableToRole = false

// ========== MICROSOFT 365 SETTINGS ==========
// Uncomment and configure for Microsoft 365 groups

// Microsoft 365 group type
// param groupTypes = ['Unified']

// Localization settings
// param preferredLanguage = 'en-US'
// param preferredDataLocation = 'NAM'
// param theme = 'Blue'

// ========== DYNAMIC MEMBERSHIP ==========
// Uncomment and configure for dynamic groups

// Dynamic membership rule for automatic user assignment
// param membershipRule = '(user.department -eq "IT") and (user.accountEnabled -eq true)'
// param membershipRuleProcessingState = 'On'

// ========== MEMBERSHIP MANAGEMENT ==========

// Owner object IDs (recommended for group management)
param ownerIds = [
  // '11111111-1111-1111-1111-111111111111'  // IT Director
  // '22222222-2222-2222-2222-222222222222'  // Security Manager
]

// Initial member object IDs
param memberIds = [
  // '33333333-3333-3333-3333-333333333333'  // IT Admin 1
  // '44444444-4444-4444-4444-444444444444'  // IT Admin 2
  // '55555555-5555-5555-5555-555555555555'  // Security Analyst
]
