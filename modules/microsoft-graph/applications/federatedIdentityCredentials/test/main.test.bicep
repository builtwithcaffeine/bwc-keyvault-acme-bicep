// Test deployment for Microsoft Graph Federated Identity Credentials Module
// This file demonstrates comprehensive usage patterns for OIDC federated identity credentials

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

@description('Environment type for deployment')
@allowed(['development', 'staging', 'production'])
param environment string = 'development'

@description('Deployment prefix for naming consistency')
param deploymentPrefix string = 'bicep-test'

@description('Organization name for GitHub/DevOps scenarios')
param organizationName string = 'contoso'

@description('Repository name for CI/CD scenarios')
param repositoryName string = 'enterprise-app'

@description('Azure DevOps organization name')
param azdoOrganization string = 'enterprise-org'

@description('Azure DevOps project name')
param azdoProject string = 'platform-services'

@description('Application ID for federated credentials (must be existing application)')
param applicationId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Graph/applications/test-app'

// ========== VARIABLES ==========

// Common audiences for Azure AD token exchange
var standardAudience = ['api://AzureADTokenExchange']

// Environment-specific branch mapping
var environmentBranches = {
  development: 'develop'
  staging: 'staging'
  production: 'main'
}

// ========== SCENARIO 1: GITHUB ACTIONS OIDC ==========

// Scenario 1.1: Branch-specific deployment
module githubBranchCredential '../main.bicep' = {
  name: '${deploymentPrefix}-github-branch'
  params: {
    applicationId: applicationId
    name: 'github-${environment}-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/${environmentBranches[environment]}'
    audiences: standardAudience
    credentialDescription: 'GitHub Actions authentication for ${environment} branch (${environmentBranches[environment]}) deployments'
  }
}

// Scenario 1.2: Environment-specific deployment
module githubEnvironmentCredential '../main.bicep' = {
  name: '${deploymentPrefix}-github-env'
  params: {
    applicationId: applicationId
    name: 'github-environment-${environment}'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:environment:${environment}'
    audiences: standardAudience
    credentialDescription: 'GitHub Actions authentication for ${environment} environment with enhanced protection'
  }
}

// Scenario 1.3: Pull request validation
module githubPullRequestCredential '../main.bicep' = {
  name: '${deploymentPrefix}-github-pr'
  params: {
    applicationId: applicationId
    name: 'github-pull-request-validation'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:pull_request'
    audiences: standardAudience
    credentialDescription: 'GitHub Actions authentication for pull request validation and testing workflows'
  }
}

// Scenario 1.4: Tag-based releases
module githubTagCredential '../main.bicep' = {
  name: '${deploymentPrefix}-github-tag'
  params: {
    applicationId: applicationId
    name: 'github-tag-releases'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/tags/v*'
    audiences: standardAudience
    credentialDescription: 'GitHub Actions authentication for version tag-based release deployments'
  }
}

// ========== SCENARIO 2: AZURE DEVOPS OIDC ==========

// Scenario 2.1: Service connection deployment
module azdoServiceConnectionCredential '../main.bicep' = {
  name: '${deploymentPrefix}-azdo-service'
  params: {
    applicationId: applicationId
    name: 'azdo-${environment}-service-connection'
    issuer: 'https://vstoken.dev.azure.com/${azdoOrganization}'
    subject: 'sc://${azdoOrganization}/${azdoProject}/${environment}-deployment'
    audiences: standardAudience
    credentialDescription: 'Azure DevOps service connection for ${environment} environment deployments'
  }
}

// Scenario 2.2: Build pipeline authentication
module azdoBuildCredential '../main.bicep' = {
  name: '${deploymentPrefix}-azdo-build'
  params: {
    applicationId: applicationId
    name: 'azdo-build-pipeline'
    issuer: 'https://vstoken.dev.azure.com/${azdoOrganization}'
    subject: 'build://${azdoOrganization}/${azdoProject}/build-pipeline'
    audiences: standardAudience
    credentialDescription: 'Azure DevOps build pipeline authentication for artifact management'
  }
}

// ========== SCENARIO 3: MULTI-CLOUD FEDERATION ==========

// Scenario 3.1: AWS cross-cloud integration
module awsFederationCredential '../main.bicep' = {
  name: '${deploymentPrefix}-aws-federation'
  params: {
    applicationId: applicationId
    name: 'aws-cross-cloud-federation'
    issuer: 'arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/${environmentBranches[environment]}'
    audiences: [
      'sts.amazonaws.com'
      'api://AzureADTokenExchange'
    ]
    credentialDescription: 'Cross-cloud federation between Azure and AWS for ${environment} environment'
  }
}

// Scenario 3.2: Google Cloud Platform integration
module gcpFederationCredential '../main.bicep' = {
  name: '${deploymentPrefix}-gcp-federation'
  params: {
    applicationId: applicationId
    name: 'gcp-workload-identity'
    issuer: 'https://accounts.google.com'
    subject: 'projects/123456789/locations/global/workloadIdentityPools/azure-pool/providers/azure-provider'
    audiences: standardAudience
    credentialDescription: 'Google Cloud Platform workload identity federation for ${environment} environment'
  }
}

// ========== SCENARIO 4: AKS WORKLOAD IDENTITY ==========

// Scenario 4.1: Kubernetes service account
module aksWorkloadCredential '../main.bicep' = {
  name: '${deploymentPrefix}-aks-workload'
  params: {
    applicationId: applicationId
    name: 'aks-${environment}-workload'
    issuer: 'https://oidc.prod-aks.azure.com/${tenant().tenantId}'
    subject: 'system:serviceaccount:${environment}:app-service-account'
    audiences: standardAudience
    credentialDescription: 'AKS workload identity for application service account in ${environment} namespace'
  }
}

// Scenario 4.2: Multiple namespace support
var namespaces = [
  'frontend'
  'backend'
  'database'
]

module aksNamespaceCredentials '../main.bicep' = [for namespace in namespaces: {
  name: '${deploymentPrefix}-aks-${namespace}'
  params: {
    applicationId: applicationId
    name: 'aks-${environment}-${namespace}'
    issuer: 'https://oidc.prod-aks.azure.com/${tenant().tenantId}'
    subject: 'system:serviceaccount:${environment}-${namespace}:${namespace}-service'
    audiences: standardAudience
    credentialDescription: 'AKS workload identity for ${namespace} service in ${environment} environment'
  }
}]

// ========== SCENARIO 5: GITLAB CI/CD ==========

// Scenario 5.1: GitLab branch deployment
module gitlabBranchCredential '../main.bicep' = {
  name: '${deploymentPrefix}-gitlab-branch'
  params: {
    applicationId: applicationId
    name: 'gitlab-${environment}-branch'
    issuer: 'https://gitlab.com'
    subject: 'project_path:${organizationName}/${repositoryName}:ref_type:branch:ref:${environmentBranches[environment]}'
    audiences: standardAudience
    credentialDescription: 'GitLab CI/CD authentication for ${environment} branch deployments'
  }
}

// Scenario 5.2: GitLab environment deployment
module gitlabEnvironmentCredential '../main.bicep' = {
  name: '${deploymentPrefix}-gitlab-env'
  params: {
    applicationId: applicationId
    name: 'gitlab-environment-${environment}'
    issuer: 'https://gitlab.com'
    subject: 'project_path:${organizationName}/${repositoryName}:environment:${environment}'
    audiences: standardAudience
    credentialDescription: 'GitLab CI/CD authentication for ${environment} environment with deployment gates'
  }
}

// ========== SCENARIO 6: CONDITIONAL DEPLOYMENTS ==========

// Production-only high-security credential
module productionSecureCredential '../main.bicep' = if (environment == 'production') {
  name: '${deploymentPrefix}-prod-secure'
  params: {
    applicationId: applicationId
    name: 'production-secure-deployment'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:environment:production'
    audiences: standardAudience
    credentialDescription: 'Production-only secure deployment credential with enhanced validation'
  }
}

// Development and staging shared credential
module devStagingCredential '../main.bicep' = if (contains(['development', 'staging'], environment)) {
  name: '${deploymentPrefix}-dev-staging'
  params: {
    applicationId: applicationId
    name: '${environment}-shared-access'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/${environmentBranches[environment]}'
    audiences: standardAudience
    credentialDescription: 'Shared credential for ${environment} environment with relaxed validation'
  }
}

// ========== OUTPUTS ==========

// GitHub Actions Credentials
@description('GitHub branch credential configuration')
output githubBranchCredential object = {
  resourceId: githubBranchCredential.outputs.resourceId
  name: githubBranchCredential.outputs.name
  issuer: githubBranchCredential.outputs.issuer
  subject: githubBranchCredential.outputs.subject
  audiences: githubBranchCredential.outputs.audiences
  description: githubBranchCredential.outputs.credentialDescription
}

@description('GitHub environment credential configuration')
output githubEnvironmentCredential object = {
  resourceId: githubEnvironmentCredential.outputs.resourceId
  name: githubEnvironmentCredential.outputs.name
  issuer: githubEnvironmentCredential.outputs.issuer
  subject: githubEnvironmentCredential.outputs.subject
  audiences: githubEnvironmentCredential.outputs.audiences
  description: githubEnvironmentCredential.outputs.credentialDescription
}

@description('GitHub pull request credential configuration')
output githubPullRequestCredential object = {
  resourceId: githubPullRequestCredential.outputs.resourceId
  name: githubPullRequestCredential.outputs.name
  issuer: githubPullRequestCredential.outputs.issuer
  subject: githubPullRequestCredential.outputs.subject
  audiences: githubPullRequestCredential.outputs.audiences
  description: githubPullRequestCredential.outputs.credentialDescription
}

@description('GitHub tag credential configuration')
output githubTagCredential object = {
  resourceId: githubTagCredential.outputs.resourceId
  name: githubTagCredential.outputs.name
  issuer: githubTagCredential.outputs.issuer
  subject: githubTagCredential.outputs.subject
  audiences: githubTagCredential.outputs.audiences
  description: githubTagCredential.outputs.credentialDescription
}

// Azure DevOps Credentials
@description('Azure DevOps service connection credential configuration')
output azdoServiceConnectionCredential object = {
  resourceId: azdoServiceConnectionCredential.outputs.resourceId
  name: azdoServiceConnectionCredential.outputs.name
  issuer: azdoServiceConnectionCredential.outputs.issuer
  subject: azdoServiceConnectionCredential.outputs.subject
  audiences: azdoServiceConnectionCredential.outputs.audiences
  description: azdoServiceConnectionCredential.outputs.credentialDescription
}

@description('Azure DevOps build credential configuration')
output azdoBuildCredential object = {
  resourceId: azdoBuildCredential.outputs.resourceId
  name: azdoBuildCredential.outputs.name
  issuer: azdoBuildCredential.outputs.issuer
  subject: azdoBuildCredential.outputs.subject
  audiences: azdoBuildCredential.outputs.audiences
  description: azdoBuildCredential.outputs.credentialDescription
}

// Multi-Cloud Federation Credentials
@description('AWS federation credential configuration')
output awsFederationCredential object = {
  resourceId: awsFederationCredential.outputs.resourceId
  name: awsFederationCredential.outputs.name
  issuer: awsFederationCredential.outputs.issuer
  subject: awsFederationCredential.outputs.subject
  audiences: awsFederationCredential.outputs.audiences
  description: awsFederationCredential.outputs.credentialDescription
}

@description('GCP federation credential configuration')
output gcpFederationCredential object = {
  resourceId: gcpFederationCredential.outputs.resourceId
  name: gcpFederationCredential.outputs.name
  issuer: gcpFederationCredential.outputs.issuer
  subject: gcpFederationCredential.outputs.subject
  audiences: gcpFederationCredential.outputs.audiences
  description: gcpFederationCredential.outputs.credentialDescription
}

// AKS Workload Identity Credentials
@description('AKS workload credential configuration')
output aksWorkloadCredential object = {
  resourceId: aksWorkloadCredential.outputs.resourceId
  name: aksWorkloadCredential.outputs.name
  issuer: aksWorkloadCredential.outputs.issuer
  subject: aksWorkloadCredential.outputs.subject
  audiences: aksWorkloadCredential.outputs.audiences
  description: aksWorkloadCredential.outputs.credentialDescription
}

@description('AKS namespace credentials configuration')
output aksNamespaceCredentials array = [for (namespace, index) in namespaces: {
  namespace: namespace
  resourceId: aksNamespaceCredentials[index].outputs.resourceId
  name: aksNamespaceCredentials[index].outputs.name
  issuer: aksNamespaceCredentials[index].outputs.issuer
  subject: aksNamespaceCredentials[index].outputs.subject
  audiences: aksNamespaceCredentials[index].outputs.audiences
  description: aksNamespaceCredentials[index].outputs.credentialDescription
}]

// GitLab CI/CD Credentials
@description('GitLab branch credential configuration')
output gitlabBranchCredential object = {
  resourceId: gitlabBranchCredential.outputs.resourceId
  name: gitlabBranchCredential.outputs.name
  issuer: gitlabBranchCredential.outputs.issuer
  subject: gitlabBranchCredential.outputs.subject
  audiences: gitlabBranchCredential.outputs.audiences
  description: gitlabBranchCredential.outputs.credentialDescription
}

@description('GitLab environment credential configuration')
output gitlabEnvironmentCredential object = {
  resourceId: gitlabEnvironmentCredential.outputs.resourceId
  name: gitlabEnvironmentCredential.outputs.name
  issuer: gitlabEnvironmentCredential.outputs.issuer
  subject: gitlabEnvironmentCredential.outputs.subject
  audiences: gitlabEnvironmentCredential.outputs.audiences
  description: gitlabEnvironmentCredential.outputs.credentialDescription
}

// Summary Information
@description('Comprehensive deployment summary')
output deploymentSummary object = {
  environment: environment
  deploymentPrefix: deploymentPrefix
  organizationName: organizationName
  repositoryName: repositoryName
  applicationId: applicationId
  credentialCategoriesDeployed: [
    'GitHub Actions (Branch, Environment, Pull Request, Tag)'
    'Azure DevOps (Service Connection, Build Pipeline)'
    'Multi-Cloud Federation (AWS, GCP)'
    'AKS Workload Identity (Main + Namespaces)'
    'GitLab CI/CD (Branch, Environment)'
    'Conditional Production/Dev-Staging'
  ]
  totalCredentialsDeployed: {
    githubActions: 4
    azureDevOps: 2
    multiCloud: 2
    aksWorkload: 4 // 1 main + 3 namespaces
    gitlab: 2
    conditional: environment == 'production' ? 1 : (contains(['development', 'staging'], environment) ? 1 : 0)
  }
  securityFeatures: [
    'Environment-specific subjects'
    'Branch protection patterns'
    'Conditional deployment controls'
    'Multi-audience support'
    'Comprehensive credential descriptions'
  ]
}
