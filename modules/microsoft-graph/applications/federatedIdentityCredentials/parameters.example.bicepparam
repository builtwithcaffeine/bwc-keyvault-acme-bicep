using 'main.bicep'

// ========== FEDERATED IDENTITY CREDENTIAL EXAMPLES ==========
// These examples demonstrate various OIDC federation patterns for passwordless authentication

// ========== EXAMPLE 1: GITHUB ACTIONS - MAIN BRANCH DEPLOYMENT ==========
param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
param name = 'github-main-branch'
param issuer = 'https://token.actions.githubusercontent.com'
param subject = 'repo:myorganization/myrepository:ref:refs/heads/main'
param audiences = ['api://AzureADTokenExchange']
param credentialDescription = 'GitHub Actions authentication for main branch deployments to production'

// ========== EXAMPLE 2: GITHUB ACTIONS - ENVIRONMENT SPECIFIC ==========
// Uncomment and modify for environment-specific deployments
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'github-production-environment'
// param issuer = 'https://token.actions.githubusercontent.com'
// param subject = 'repo:myorganization/myrepository:environment:production'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'GitHub Actions authentication for production environment with enhanced protection'

// ========== EXAMPLE 3: GITHUB ACTIONS - PULL REQUEST VALIDATION ==========
// Uncomment and modify for pull request validation workflows
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'github-pull-request'
// param issuer = 'https://token.actions.githubusercontent.com'
// param subject = 'repo:myorganization/myrepository:pull_request'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'GitHub Actions authentication for pull request validation and testing'

// ========== EXAMPLE 4: AZURE DEVOPS - SERVICE CONNECTION ==========
// Uncomment and modify for Azure DevOps service connections
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'azdo-production-deployment'
// param issuer = 'https://vstoken.dev.azure.com/myorganization'
// param subject = 'sc://myorganization/myproject/production-serviceconnection'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'Azure DevOps service connection for production deployments'

// ========== EXAMPLE 5: AKS WORKLOAD IDENTITY ==========
// Uncomment and modify for AKS workload identity scenarios
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'aks-production-workload'
// param issuer = 'https://oidc.prod-aks.azure.com/12345678-1234-1234-1234-123456789012'
// param subject = 'system:serviceaccount:production:backend-service'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'AKS workload identity for backend service in production namespace'

// ========== EXAMPLE 6: AWS CROSS-CLOUD FEDERATION ==========
// Uncomment and modify for AWS integration scenarios
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'aws-github-federation'
// param issuer = 'arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com'
// param subject = 'repo:myorganization/aws-integration:ref:refs/heads/main'
// param audiences = ['sts.amazonaws.com', 'api://AzureADTokenExchange']
// param credentialDescription = 'Cross-cloud federation between Azure and AWS via GitHub Actions'

// ========== EXAMPLE 7: GITLAB CI/CD ==========
// Uncomment and modify for GitLab CI/CD scenarios
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'gitlab-main-branch'
// param issuer = 'https://gitlab.com'
// param subject = 'project_path:mygroup/myproject:ref_type:branch:ref:main'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'GitLab CI/CD authentication for main branch deployments'

// ========== EXAMPLE 8: TAG-BASED RELEASES ==========
// Uncomment and modify for version tag-based deployments
// param applicationId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example/providers/Microsoft.Graph/applications/my-app'
// param name = 'github-tag-releases'
// param issuer = 'https://token.actions.githubusercontent.com'
// param subject = 'repo:myorganization/myrepository:ref:refs/tags/v*'
// param audiences = ['api://AzureADTokenExchange']
// param credentialDescription = 'GitHub Actions authentication for version tag-based release deployments'

// ========== USAGE NOTES ==========
/*
KEY CONCEPTS:
1. Application ID: Must reference an existing Azure AD application
2. Credential Name: Must be unique within the application
3. Issuer: The OIDC issuer URL from the external identity provider
4. Subject: The subject claim pattern that must match incoming tokens
5. Audiences: List of valid audiences for token validation

SECURITY BEST PRACTICES:
- Use specific subject patterns (avoid wildcards where possible)
- Implement environment-based subject isolation
- Regular rotation of federated credentials
- Monitor and audit credential usage
- Follow principle of least privilege

COMMON SUBJECT PATTERNS:
GitHub Actions:
  - Branch: 'repo:owner/repo:ref:refs/heads/branch-name'
  - Environment: 'repo:owner/repo:environment:environment-name'
  - Pull Request: 'repo:owner/repo:pull_request'
  - Tag: 'repo:owner/repo:ref:refs/tags/tag-pattern'

Azure DevOps:
  - Service Connection: 'sc://organization/project/serviceconnection-name'
  - Build Pipeline: 'build://organization/project/pipeline-name'

AKS Workload Identity:
  - Service Account: 'system:serviceaccount:namespace:serviceaccount-name'

TROUBLESHOOTING:
- Verify subject claim matches exactly (case-sensitive)
- Check issuer URL accessibility and correctness
- Ensure audiences include required values
- Confirm credential name uniqueness within application
*/
