/*
  Test deployment for Microsoft Graph Users Module
  
  This file demonstrates comprehensive usage patterns for user references
  including individual users, team assignments, department structures,
  role-based access control, and integration with other modules.
  
  Prerequisites:
  - Microsoft Graph Bicep extension v1.0 installed
  - Appropriate Azure AD permissions (User.Read.All or Directory.Read.All)
  - Valid User Principal Names that exist in your Azure AD tenant
  - Test users should be replaced with actual users from your environment
  
  Usage:
  az deployment group create \
    --resource-group myResourceGroup \
    --template-file main.test.bicep \
    --parameters @test.parameters.json
*/

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

// Environment and naming parameters
@description('Environment name for deployment naming')
param environment string = 'test'

@description('Organization name for resource naming')
param organizationName string = 'contoso'

// Individual user references
@description('CEO User Principal Name')
param ceoUserPrincipalName string = 'ceo@contoso.com'

@description('CTO User Principal Name')
param ctoUserPrincipalName string = 'cto@contoso.com'

@description('IT Administrator User Principal Name')
param itAdminUserPrincipalName string = 'it.admin@contoso.com'

@description('Project Manager User Principal Name')
param projectManagerUserPrincipalName string = 'project.manager@contoso.com'

// Team and department user lists
@description('Development team User Principal Names')
param developmentTeam array = [
  'lead.developer@contoso.com'
  'senior.dev1@contoso.com'
  'senior.dev2@contoso.com'
  'junior.dev1@contoso.com'
  'qa.engineer@contoso.com'
]

@description('Sales team User Principal Names')
param salesTeam array = [
  'sales.manager@contoso.com'
  'sales.rep1@contoso.com'
  'sales.rep2@contoso.com'
  'sales.admin@contoso.com'
]

@description('HR team User Principal Names')
param hrTeam array = [
  'hr.director@contoso.com'
  'hr.manager@contoso.com'
  'recruiter@contoso.com'
  'benefits.admin@contoso.com'
]

@description('External partner User Principal Names (guest users)')
param externalPartners array = [
  'partner1@external.com'
  'consultant@vendor.com'
]

// Role-based user assignments
@description('Global Administrator User Principal Names')
param globalAdmins array = [
  'global.admin1@contoso.com'
  'global.admin2@contoso.com'
]

@description('Application Administrator User Principal Names')
param applicationAdmins array = [
  'app.admin1@contoso.com'
  'app.admin2@contoso.com'
]

// ========== VARIABLES ==========

var deploymentPrefix = '${organizationName}-${environment}'

// Combine all users for summary reporting
var allUsers = concat(
  [ceoUserPrincipalName, ctoUserPrincipalName, itAdminUserPrincipalName, projectManagerUserPrincipalName],
  developmentTeam,
  salesTeam,
  hrTeam,
  externalPartners,
  globalAdmins,
  applicationAdmins
)

// ========== SCENARIO 1: EXECUTIVE LEADERSHIP ==========

// Scenario 1.1: CEO User Reference
module ceoUser '../main.bicep' = {
  name: '${deploymentPrefix}-ceo-user'
  params: {
    userPrincipalName: ceoUserPrincipalName
  }
}

// Scenario 1.2: CTO User Reference
module ctoUser '../main.bicep' = {
  name: '${deploymentPrefix}-cto-user'
  params: {
    userPrincipalName: ctoUserPrincipalName
  }
}

// ========== SCENARIO 2: ADMINISTRATIVE USERS ==========

// Scenario 2.1: IT Administrator
module itAdminUser '../main.bicep' = {
  name: '${deploymentPrefix}-it-admin'
  params: {
    userPrincipalName: itAdminUserPrincipalName
  }
}

// Scenario 2.2: Project Manager
module projectManagerUser '../main.bicep' = {
  name: '${deploymentPrefix}-project-manager'
  params: {
    userPrincipalName: projectManagerUserPrincipalName
  }
}

// ========== SCENARIO 3: DEVELOPMENT TEAM ==========

// Reference all development team members
module developmentTeamUsers '../main.bicep' = [for (developer, index) in developmentTeam: {
  name: '${deploymentPrefix}-dev-${index}'
  params: {
    userPrincipalName: developer
  }
}]

// ========== SCENARIO 4: SALES TEAM ==========

// Reference all sales team members
module salesTeamUsers '../main.bicep' = [for (salesperson, index) in salesTeam: {
  name: '${deploymentPrefix}-sales-${index}'
  params: {
    userPrincipalName: salesperson
  }
}]

// ========== SCENARIO 5: HR TEAM ==========

// Reference all HR team members
module hrTeamUsers '../main.bicep' = [for (hrMember, index) in hrTeam: {
  name: '${deploymentPrefix}-hr-${index}'
  params: {
    userPrincipalName: hrMember
  }
}]

// ========== SCENARIO 6: EXTERNAL PARTNERS ==========

// Reference external partner users (guest users)
module externalPartnerUsers '../main.bicep' = [for (partner, index) in externalPartners: {
  name: '${deploymentPrefix}-partner-${index}'
  params: {
    userPrincipalName: partner
  }
}]

// ========== SCENARIO 7: GLOBAL ADMINISTRATORS ==========

// Reference Global Administrator users
module globalAdminUsers '../main.bicep' = [for (admin, index) in globalAdmins: {
  name: '${deploymentPrefix}-global-admin-${index}'
  params: {
    userPrincipalName: admin
  }
}]

// ========== SCENARIO 8: APPLICATION ADMINISTRATORS ==========

// Reference Application Administrator users
module applicationAdminUsers '../main.bicep' = [for (admin, index) in applicationAdmins: {
  name: '${deploymentPrefix}-app-admin-${index}'
  params: {
    userPrincipalName: admin
  }
}]

// ========== SCENARIO 9: BATCH USER PROCESSING ==========

// Process all unique users from the combined list
var uniqueUsers = union(
  [ceoUserPrincipalName],
  [ctoUserPrincipalName], 
  [itAdminUserPrincipalName],
  [projectManagerUserPrincipalName],
  developmentTeam,
  salesTeam,
  hrTeam,
  externalPartners,
  globalAdmins,
  applicationAdmins
)

// Reference a subset of users for batch processing demonstration
module batchUserProcessing '../main.bicep' = [for (user, index) in take(uniqueUsers, 5): {
  name: '${deploymentPrefix}-batch-${index}'
  params: {
    userPrincipalName: user
  }
}]

// ========== SCENARIO 10: CONDITIONAL USER REFERENCES ==========

// Conditionally reference users based on environment
module productionOnlyUsers '../main.bicep' = [for admin in globalAdmins: if (environment == 'production') {
  name: '${deploymentPrefix}-prod-admin-${replace(admin, '@', '-at-')}'
  params: {
    userPrincipalName: admin
  }
}]

// ========== OUTPUTS ==========

// Executive Leadership Outputs
@description('CEO User Information')
output ceoUser object = {
  resourceId: ceoUser.outputs.resourceId
  userId: ceoUser.outputs.userId
  userPrincipalName: ceoUser.outputs.userPrincipalName
  displayName: ceoUser.outputs.displayName
  mail: ceoUser.outputs.mail
  givenName: ceoUser.outputs.givenName
  surname: ceoUser.outputs.surname
  jobTitle: ceoUser.outputs.jobTitle
  officeLocation: ceoUser.outputs.officeLocation
  businessPhones: ceoUser.outputs.businessPhones
  mobilePhone: ceoUser.outputs.mobilePhone
  preferredLanguage: ceoUser.outputs.preferredLanguage
}

@description('CTO User Information')
output ctoUser object = {
  resourceId: ctoUser.outputs.resourceId
  userId: ctoUser.outputs.userId
  userPrincipalName: ctoUser.outputs.userPrincipalName
  displayName: ctoUser.outputs.displayName
  mail: ctoUser.outputs.mail
  givenName: ctoUser.outputs.givenName
  surname: ctoUser.outputs.surname
  jobTitle: ctoUser.outputs.jobTitle
  officeLocation: ctoUser.outputs.officeLocation
  businessPhones: ctoUser.outputs.businessPhones
  mobilePhone: ctoUser.outputs.mobilePhone
  preferredLanguage: ctoUser.outputs.preferredLanguage
}

// Administrative Users Outputs
@description('IT Administrator User Information')
output itAdminUser object = {
  resourceId: itAdminUser.outputs.resourceId
  userId: itAdminUser.outputs.userId
  userPrincipalName: itAdminUser.outputs.userPrincipalName
  displayName: itAdminUser.outputs.displayName
  mail: itAdminUser.outputs.mail
  jobTitle: itAdminUser.outputs.jobTitle
}

@description('Project Manager User Information')
output projectManagerUser object = {
  resourceId: projectManagerUser.outputs.resourceId
  userId: projectManagerUser.outputs.userId
  userPrincipalName: projectManagerUser.outputs.userPrincipalName
  displayName: projectManagerUser.outputs.displayName
  mail: projectManagerUser.outputs.mail
  jobTitle: projectManagerUser.outputs.jobTitle
}

// Team Collections Outputs
@description('Development Team Users Information')
output developmentTeamUsers array = [for (developer, index) in developmentTeam: {
  resourceId: developmentTeamUsers[index].outputs.resourceId
  userId: developmentTeamUsers[index].outputs.userId
  userPrincipalName: developmentTeamUsers[index].outputs.userPrincipalName
  displayName: developmentTeamUsers[index].outputs.displayName
  mail: developmentTeamUsers[index].outputs.mail
  jobTitle: developmentTeamUsers[index].outputs.jobTitle
}]

@description('Sales Team Users Information')
output salesTeamUsers array = [for (salesperson, index) in salesTeam: {
  resourceId: salesTeamUsers[index].outputs.resourceId
  userId: salesTeamUsers[index].outputs.userId
  userPrincipalName: salesTeamUsers[index].outputs.userPrincipalName
  displayName: salesTeamUsers[index].outputs.displayName
  mail: salesTeamUsers[index].outputs.mail
  jobTitle: salesTeamUsers[index].outputs.jobTitle
}]

@description('HR Team Users Information')
output hrTeamUsers array = [for (hrMember, index) in hrTeam: {
  resourceId: hrTeamUsers[index].outputs.resourceId
  userId: hrTeamUsers[index].outputs.userId
  userPrincipalName: hrTeamUsers[index].outputs.userPrincipalName
  displayName: hrTeamUsers[index].outputs.displayName
  mail: hrTeamUsers[index].outputs.mail
  jobTitle: hrTeamUsers[index].outputs.jobTitle
}]

// External Partners Output
@description('External Partner Users Information')
output externalPartnerUsers array = [for (partner, index) in externalPartners: {
  resourceId: externalPartnerUsers[index].outputs.resourceId
  userId: externalPartnerUsers[index].outputs.userId
  userPrincipalName: externalPartnerUsers[index].outputs.userPrincipalName
  displayName: externalPartnerUsers[index].outputs.displayName
  mail: externalPartnerUsers[index].outputs.mail
}]

// Administrative Role Outputs
@description('Global Administrator Users Information')
output globalAdminUsers array = [for (admin, index) in globalAdmins: {
  resourceId: globalAdminUsers[index].outputs.resourceId
  userId: globalAdminUsers[index].outputs.userId
  userPrincipalName: globalAdminUsers[index].outputs.userPrincipalName
  displayName: globalAdminUsers[index].outputs.displayName
  mail: globalAdminUsers[index].outputs.mail
  jobTitle: globalAdminUsers[index].outputs.jobTitle
}]

@description('Application Administrator Users Information')
output applicationAdminUsers array = [for (admin, index) in applicationAdmins: {
  resourceId: applicationAdminUsers[index].outputs.resourceId
  userId: applicationAdminUsers[index].outputs.userId
  userPrincipalName: applicationAdminUsers[index].outputs.userPrincipalName
  displayName: applicationAdminUsers[index].outputs.displayName
  mail: applicationAdminUsers[index].outputs.mail
  jobTitle: applicationAdminUsers[index].outputs.jobTitle
}]

// Batch Processing Output
@description('Batch Processed Users Information (subset for demonstration)')
output batchProcessedUsers array = [for (user, index) in take(uniqueUsers, 5): {
  resourceId: batchUserProcessing[index].outputs.resourceId
  userId: batchUserProcessing[index].outputs.userId
  userPrincipalName: batchUserProcessing[index].outputs.userPrincipalName
  displayName: batchUserProcessing[index].outputs.displayName
  mail: batchUserProcessing[index].outputs.mail
}]

// Summary Statistics
@description('User deployment summary and statistics')
output userSummary object = {
  totalUsers: length(uniqueUsers)
  executiveCount: 2
  administrativeCount: 2
  developmentTeamCount: length(developmentTeam)
  salesTeamCount: length(salesTeam)
  hrTeamCount: length(hrTeam)
  externalPartnersCount: length(externalPartners)
  globalAdminsCount: length(globalAdmins)
  applicationAdminsCount: length(applicationAdmins)
  batchProcessedCount: length(take(uniqueUsers, 5))
}

// Environment-specific outputs
@description('Deployment metadata and environment information')
output deploymentMetadata object = {
  environment: environment
  deploymentPrefix: deploymentPrefix
  uniqueUserCount: length(uniqueUsers)
}
