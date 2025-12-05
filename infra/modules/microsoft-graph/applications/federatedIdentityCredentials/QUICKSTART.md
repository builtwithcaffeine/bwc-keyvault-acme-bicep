# 🚀 Quick Start Guide

## Microsoft Graph Federated Identity Credentials Module

Configure passwordless authentication for CI/CD and multi-cloud scenarios in **under 5 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Azure AD permissions: **Application Administrator** or **Global Administrator**
- External identity provider access (GitHub, Azure DevOps, AWS, GCP, etc.)
- Understanding of OIDC token claims

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: GitHub Actions OIDC Setup (2 minutes)

### Step 1: Create GitHub Parameter File

Create `github-oidc.bicepparam`:

```bicep
using 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep'

// GitHub Actions OIDC for main branch deployments
param applicationDisplayName = 'MyApp-GitHub-Production'
param applicationUniqueName = 'myapp-github-prod'
param name = 'github-main-branch'
param issuer = 'https://token.actions.githubusercontent.com'
param subject = 'repo:myorg/myrepo:ref:refs/heads/main'
param audiences = ['api://AzureADTokenExchange']
param credentialDescription = 'GitHub Actions OIDC for production deployments from main branch'
```

### Step 2: Deploy GitHub OIDC

```bash
# Deploy GitHub Actions OIDC configuration
az deployment group create \
  --resource-group "rg-github-oidc" \
  --template-file "modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep" \
  --parameters "github-oidc.bicepparam" \
  --name "github-oidc-deployment"
```

### Step 3: Get Application ID for GitHub Secrets

```bash
# Get the application ID from deployment output
APP_ID=$(az deployment group show \
  --resource-group "rg-github-oidc" \
  --name "github-oidc-deployment" \
  --query "properties.outputs.applicationId.value" -o tsv)

echo "Add this to GitHub Secrets as AZURE_CLIENT_ID: $APP_ID"
echo "Also add AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID"
```

### Step 4: Configure GitHub Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Azure
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Deploy Resources
        run: |
          az group list --query "[].name" -o table
          echo "🎉 Passwordless authentication successful!"
```

**🎉 GitHub Actions can now authenticate to Azure without secrets!**

---

## 🎯 Option 2: Multi-Environment GitHub Setup (3 minutes)

### Step 1: Create Multi-Environment Template

Create `multi-env-github.bicep`:

```bicep
targetScope = 'resourceGroup'

param repositoryName string
param organizationName string

// Development environment
module devOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'dev-github-oidc'
  params: {
    applicationDisplayName: '${repositoryName}-GitHub-Development'
    applicationUniqueName: '${toLower(repositoryName)}-github-dev'
    name: 'github-develop-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/develop'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for development deployments'
  }
}

// Staging environment
module stagingOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'staging-github-oidc'
  params: {
    applicationDisplayName: '${repositoryName}-GitHub-Staging'
    applicationUniqueName: '${toLower(repositoryName)}-github-staging'
    name: 'github-staging-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/staging'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for staging deployments'
  }
}

// Production environment (with environment protection)
module prodOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'prod-github-oidc'
  params: {
    applicationDisplayName: '${repositoryName}-GitHub-Production'
    applicationUniqueName: '${toLower(repositoryName)}-github-prod'
    name: 'github-production-env'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:environment:production'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for production deployments with environment protection'
  }
}

output devApplicationId string = devOidc.outputs.applicationId
output stagingApplicationId string = stagingOidc.outputs.applicationId
output prodApplicationId string = prodOidc.outputs.applicationId
```

### Step 2: Deploy Multi-Environment Setup

```bash
# Deploy all environments
az deployment group create \
  --resource-group "rg-multi-env" \
  --template-file "multi-env-github.bicep" \
  --parameters repositoryName="my-app" organizationName="myorg" \
  --name "multi-env-github-deployment"
```

**🎉 Multi-environment GitHub OIDC setup complete!**

---

## 🎯 Option 3: Multi-Cloud Federation (5 minutes)

### Step 1: Create Multi-Provider Template

Create `multi-cloud-federation.bicep`:

```bicep
targetScope = 'resourceGroup'

param applicationBaseName string
param projectName string

// GitHub Actions
module githubOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'github-federation'
  params: {
    applicationDisplayName: '${applicationBaseName}-GitHub'
    applicationUniqueName: '${toLower(applicationBaseName)}-github'
    name: 'github-actions-main'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${projectName}:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions CI/CD pipeline'
  }
}

// Azure DevOps
module azdoOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'azdo-federation'
  params: {
    applicationDisplayName: '${applicationBaseName}-AzureDevOps'
    applicationUniqueName: '${toLower(applicationBaseName)}-azdo'
    name: 'azdo-service-connection'
    issuer: 'https://vstoken.dev.azure.com/${projectName}'
    subject: 'sc://${projectName}/${projectName}/${applicationBaseName}-connection'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Azure DevOps service connection'
  }
}

// AWS (cross-cloud scenario)
module awsOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'aws-federation'
  params: {
    applicationDisplayName: '${applicationBaseName}-AWS'
    applicationUniqueName: '${toLower(applicationBaseName)}-aws'
    name: 'aws-iam-role'
    issuer: 'https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE'
    subject: 'system:serviceaccount:default:${applicationBaseName}-service'
    audiences: ['sts.amazonaws.com']
    credentialDescription: 'AWS EKS service account federation'
  }
}

// Google Cloud Platform
module gcpOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'gcp-federation'
  params: {
    applicationDisplayName: '${applicationBaseName}-GCP'
    applicationUniqueName: '${toLower(applicationBaseName)}-gcp'
    name: 'gcp-service-account'
    issuer: 'https://accounts.google.com'
    subject: '${projectName}@${projectName}.iam.gserviceaccount.com'
    audiences: ['//iam.googleapis.com/projects/${projectName}/locations/global/workloadIdentityPools/azure-pool/providers/azure-provider']
    credentialDescription: 'Google Cloud Platform workload identity'
  }
}

output githubAppId string = githubOidc.outputs.applicationId
output azdoAppId string = azdoOidc.outputs.applicationId
output awsAppId string = awsOidc.outputs.applicationId
output gcpAppId string = gcpOidc.outputs.applicationId
```

### Step 2: Deploy Multi-Cloud Federation

```bash
# Deploy multi-cloud federation setup
az deployment group create \
  --resource-group "rg-multi-cloud" \
  --template-file "multi-cloud-federation.bicep" \
  --parameters applicationBaseName="Enterprise-App" projectName="my-project" \
  --name "multi-cloud-federation-deployment"
```

**🎉 Multi-cloud federation configured for seamless identity across platforms!**

---

## 🛠️ Common Operations

### Validate OIDC Configuration

```bash
# Test GitHub Actions token (from workflow)
curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | \
  jq -r .value | \
  curl -s "https://jwt.io" -d @-

# List federated credentials for an application
az ad app federated-credential list --id <app-id> \
  --query "[].{name:name,issuer:issuer,subject:subject}" -o table
```

### Manage Federated Credentials

```bash
# Get application details
az ad app show --id <app-id> \
  --query "{displayName:displayName,appId:appId,id:id}"

# Update federated credential subject
az ad app federated-credential update \
  --id <app-id> \
  --federated-credential-id <credential-id> \
  --subject "repo:neworg/newrepo:ref:refs/heads/main"

# Delete federated credential
az ad app federated-credential delete \
  --id <app-id> \
  --federated-credential-id <credential-id>
```

### Debug Authentication Issues

```bash
# Decode OIDC token to check claims
echo $OIDC_TOKEN | jq -R 'split(".") | .[1] | @base64d | fromjson'

# Test Azure login with OIDC
az login --service-principal \
  --username <app-id> \
  --tenant <tenant-id> \
  --federated-token $OIDC_TOKEN
```

## 🔍 Troubleshooting

### Issue: Invalid Subject Claim

**Error**: `AADSTS70021: No matching federated identity record found`

**Solution**: Verify the subject claim format matches your provider:

```bash
# GitHub Actions subject formats
repo:owner/repo:ref:refs/heads/main                    # Branch
repo:owner/repo:ref:refs/tags/v1.0                     # Tag  
repo:owner/repo:environment:production                 # Environment
repo:owner/repo:pull_request                          # Pull request

# Azure DevOps subject format
sc://organization/project/service-connection-name
```

### Issue: Wrong Issuer URL

**Error**: `AADSTS70021: Invalid issuer`

**Solution**: Use the correct issuer for your provider:

```bash
# Common issuers
GitHub Actions:     https://token.actions.githubusercontent.com
Azure DevOps:       https://vstoken.dev.azure.com/<organization>
AWS EKS:           https://oidc.eks.<region>.amazonaws.com/id/<cluster-id>
Google Cloud:      https://accounts.google.com
GitLab:            https://gitlab.com
```

### Issue: Audience Mismatch

**Error**: `AADSTS700224: Invalid audience`

**Solution**: Verify the audience configuration:

```bash
# Standard audiences
Azure:             api://AzureADTokenExchange
AWS:               sts.amazonaws.com
Google Cloud:      //iam.googleapis.com/projects/<project>/locations/global/workloadIdentityPools/<pool>/providers/<provider>
```

### Issue: Token Lifetime

**Error**: `AADSTS700024: Token lifetime too long`

**Solution**: Check your provider's token configuration:

```bash
# GitHub Actions tokens typically valid for 1 hour
# Azure DevOps tokens valid for 1 hour by default
# Ensure your workflows complete within token lifetime
```

## 🔗 Quick Reference

### Provider Subject Patterns

| Provider | Subject Pattern | Example |
|----------|----------------|---------|
| GitHub Actions | `repo:org/repo:ref:refs/heads/branch` | `repo:myorg/myapp:ref:refs/heads/main` |
| Azure DevOps | `sc://org/project/connection` | `sc://myorg/myproject/azure-connection` |
| AWS EKS | `system:serviceaccount:namespace:serviceaccount` | `system:serviceaccount:default:app-service` |
| Google Cloud | `project-number.svc.id.goog[namespace/serviceaccount]` | `123456789.svc.id.goog[default/workload-identity-sa]` |
| GitLab | `project_path:group/project:ref_type:branch:ref:main` | `project_path:mygroup/myproject:ref_type:branch:ref:main` |

### Essential Commands

```bash
# Get application ID
az ad app list --filter "displayName eq 'App Name'" --query "[0].appId" -o tsv

# List federated credentials
az ad app federated-credential list --id <app-id> --query "[].name" -o table

# Test OIDC token claims
echo $TOKEN | jq -R 'split(".") | .[1] | @base64d | fromjson'
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced federation scenarios  
- 🏢 **[Applications](../QUICKSTART.md)** - Parent application module
- 🔐 **[App Role Assignments](../../appRoleAssignedTo/QUICKSTART.md)** - Assign permissions
- 👥 **[Service Principals](../../servicePrincipals/QUICKSTART.md)** - Application identities

## 💡 Pro Tips

1. **Use environment-specific subjects** - Different credentials for dev/staging/prod
2. **Implement environment protection** - Require approvals for production deployments
3. **Monitor authentication** - Set up alerts for failed OIDC authentications
4. **Rotate regularly** - Update credentials periodically for security
5. **Test thoroughly** - Validate all subject patterns work as expected
6. **Document patterns** - Keep track of subject claim formats for each provider
7. **Use descriptive names** - Clear naming helps with credential management

---

**🔐 Your federated identity credentials are configured for passwordless authentication!** 🚀
