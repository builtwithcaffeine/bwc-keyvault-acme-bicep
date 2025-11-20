// Microsoft Graph Groups Module
// Creates Azure AD groups using Microsoft Graph Bicep

metadata name = 'Microsoft Graph Groups'
metadata description = 'Creates and configures Azure AD groups'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. Display name for the group')
param displayName string

@description('Required. Security Group Name ')
param groupName string

@description('Optional. Description of the group')
param groupDescription string = ''

@description('Required. Mail nickname for the group')
param mailNickname string

@description('Optional. Whether the group is mail-enabled')
param mailEnabled bool = false

@description('Optional. Whether the group is security-enabled')
param securityEnabled bool = true

@description('Optional. Group types (e.g., Unified for Microsoft 365 groups)')
param groupTypes array = []

@description('Optional. Whether the group can be assigned to roles')
param isAssignableToRole bool = false

//@description('Optional. Whether the group is management restricted')
//param isManagementRestricted bool = false

@description('Optional. Group visibility')
@allowed([
  'Private'
  'Public'
  'HiddenMembership'
])
param visibility string = 'Private'

@description('Optional. Group classification')
param classification string = ''

@description('Optional. Preferred language for the group')
param preferredLanguage string = ''

@description('Optional. Preferred data location for the group')
param preferredDataLocation string = ''

@description('Optional. Group theme')
param theme string = ''

@description('Optional. Membership rule for dynamic groups')
param membershipRule string = ''

@description('Optional. Membership rule processing state for dynamic groups')
@allowed([
  'On'
  'Paused'
])
param membershipRuleProcessingState string = 'On'

@description('Optional. Owner object IDs')
param ownerIds array = []

@description('Optional. Member object IDs')
param memberIds array = []

// ========== VARIABLES ==========

// Configure owners relationship if provided
var ownersConfig = !empty(ownerIds) ? {
  relationships: ownerIds
  relationshipSemantics: 'append'
} : null

// Configure members relationship if provided
var membersConfig = !empty(memberIds) ? {
  relationships: memberIds
  relationshipSemantics: 'append'
} : null

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph Group')
resource group 'Microsoft.Graph/groups@v1.0' = {
  uniqueName: groupName
  displayName: displayName
  description: !empty(groupDescription) ? groupDescription : null
  mailNickname: mailNickname
  mailEnabled: mailEnabled
  securityEnabled: securityEnabled
  groupTypes: !empty(groupTypes) ? groupTypes : []
  isAssignableToRole: isAssignableToRole
  //isManagementRestricted: isManagementRestricted
  visibility: visibility
  classification: !empty(classification) ? classification : null
  preferredLanguage: !empty(preferredLanguage) ? preferredLanguage : null
  preferredDataLocation: !empty(preferredDataLocation) ? preferredDataLocation : null
  theme: !empty(theme) ? theme : null
  membershipRule: !empty(membershipRule) ? membershipRule : null
  membershipRuleProcessingState: !empty(membershipRule) ? membershipRuleProcessingState : null
  owners: ownersConfig
  members: membersConfig
}

// ========== OUTPUTS ==========

@description('The resource ID of the group')
output resourceId string = group.id

@description('The group ID')
output groupId string = group.id

@description('The display name of the group')
output displayName string = group.displayName

@description('The mail nickname of the group')
output mailNickname string = group.mailNickname

@description('Whether the group is mail-enabled')
output mailEnabled bool = group.mailEnabled

@description('Whether the group is security-enabled')
output securityEnabled bool = group.securityEnabled

@description('The group types')
output groupTypes array = group.groupTypes

@description('Whether the group can be assigned to roles')
output isAssignableToRole bool = group.isAssignableToRole

// @description('Whether the group is management restricted')
// output isManagementRestricted bool = group.isManagementRestricted

@description('The group visibility')
output visibility string = group.visibility
