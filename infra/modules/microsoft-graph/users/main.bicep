// Microsoft Graph Users Module
// References existing Azure AD users using Microsoft Graph Bicep

metadata name = 'Microsoft Graph Users'
metadata description = 'References existing Azure AD users for use in other resources'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. User principal name of the existing user')
param userPrincipalName string

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph User Reference')
resource user 'Microsoft.Graph/users@v1.0' existing = {
  userPrincipalName: userPrincipalName
}

// ========== OUTPUTS ==========

@description('The resource ID of the user')
output resourceId string = user.id

@description('The user ID (object ID)')
output userId string = user.id

@description('The user principal name')
output userPrincipalName string = user.userPrincipalName

@description('The display name of the user')
output displayName string = user.displayName

@description('The mail address of the user')
output mail string = user.mail

@description('The given name of the user')
output givenName string = user.givenName

@description('The surname of the user')
output surname string = user.surname

@description('The job title of the user')
output jobTitle string = user.jobTitle

@description('The mobile phone number of the user')
output mobilePhone string = user.mobilePhone

@description('The office location of the user')
output officeLocation string = user.officeLocation

@description('The preferred language of the user')
output preferredLanguage string = user.preferredLanguage

@description('The business phone numbers of the user')
output businessPhones array = user.businessPhones
