# 🚀 Quick Start Guide

## Microsoft Graph Federated Identity Credentials Module

Configure passwordless authentication for CI/CD and workload identities in **under 5 minutes**.

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Microsoft Entra permissions: **Application Administrator** or **Global Administrator**
- Existing application identifier (`applicationId`) from the parent `applications` module
- OIDC issuer and subject details from your identity provider

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: GitHub Actions OIDC (2 minutes)

### Step 1: Create parameter file

Create `github-oidc.bicepparam`:

```bicep
using 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep'

// Application identifier from parent applications module (for example: app.outputs.objectId)
param applicationId = '00000000-0000-0000-0000-000000000000'
param name = 'github-main-branch'
param issuer = 'https://token.actions.githubusercontent.com'
param subject = 'repo:myorg/myrepo:ref:refs/heads/main'
param audiences = ['api://AzureADTokenExchange']
param credentialDescription = 'GitHub Actions OIDC for production deployments from main branch'
```

### Step 2: Deploy

```bash
az deployment group create \
  --resource-group "rg-github-oidc" \
  --template-file "modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep" \
  --parameters "github-oidc.bicepparam" \
  --name "github-oidc-deployment"
```

### Step 3: Verify outputs

```bash
az deployment group show \
  --resource-group "rg-github-oidc" \
  --name "github-oidc-deployment" \
  --query "properties.outputs.{resourceId:resourceId.value,name:name.value,issuer:issuer.value,subject:subject.value,audiences:audiences.value}"
```

---

## 🎯 Option 2: Multi-environment credentials (3 minutes)

Create `multi-env-oidc.bicep`:

```bicep
targetScope = 'resourceGroup'

@description('Application identifier from the applications module output')
param applicationId string
param organizationName string
param repositoryName string

module devOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'dev-github-oidc'
  params: {
    applicationId: applicationId
    name: 'github-develop-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/develop'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for development deployments'
  }
}

module stagingOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'staging-github-oidc'
  params: {
    applicationId: applicationId
    name: 'github-staging-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:ref:refs/heads/staging'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for staging deployments'
  }
}

module prodOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'prod-github-oidc'
  params: {
    applicationId: applicationId
    name: 'github-production-env'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${organizationName}/${repositoryName}:environment:production'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions OIDC for production deployments with environment protection'
  }
}

output devCredentialName string = devOidc.outputs.name
output stagingCredentialName string = stagingOidc.outputs.name
output prodCredentialName string = prodOidc.outputs.name
```

---

## 🎯 Option 3: Multi-provider federation (5 minutes)

Create `multi-provider-oidc.bicep`:

```bicep
targetScope = 'resourceGroup'

param applicationId string
param projectName string

module githubOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'github-federation'
  params: {
    applicationId: applicationId
    name: 'github-actions-main'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${projectName}:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions CI/CD pipeline'
  }
}

module azdoOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'azdo-federation'
  params: {
    applicationId: applicationId
    name: 'azdo-service-connection'
    issuer: 'https://vstoken.dev.azure.com/${projectName}'
    subject: 'sc://${projectName}/${projectName}/azure-connection'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Azure DevOps service connection'
  }
}

module awsOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'aws-federation'
  params: {
    applicationId: applicationId
    name: 'aws-iam-role'
    issuer: 'https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE'
    subject: 'system:serviceaccount:default:workload-serviceaccount'
    audiences: ['sts.amazonaws.com']
    credentialDescription: 'AWS EKS service account federation'
  }
}

output githubCredential string = githubOidc.outputs.name
output azdoCredential string = azdoOidc.outputs.name
output awsCredential string = awsOidc.outputs.name
```

## 🛠️ Common operations

```bash
# List federated credentials for an application
az ad app federated-credential list --id <application-id> \
  --query "[].{name:name,issuer:issuer,subject:subject}" -o table

# Delete a federated credential
az ad app federated-credential delete \
  --id <application-id> \
  --federated-credential-id <credential-id>
```

## 🔍 Troubleshooting

### No matching federated identity record found

`AADSTS70021: No matching federated identity record found`

- Verify `issuer` and `subject` match token claims exactly (case-sensitive)
- Verify `audiences` includes `api://AzureADTokenExchange` for Azure token exchange scenarios
- Verify the credential is attached to the expected parent application identifier

### Invalid audience

`AADSTS700224: Invalid audience`

- Ensure the workflow token requests the same audience configured in this module

## 🔗 Next steps

- 📖 **[Full Documentation](README.md)** - Complete parameter/output reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Validation scenarios
- 🏢 **[Applications Module](../README.md)** - Create/retrieve parent application first
- 🔐 **[App Role Assignments](../../appRoleAssignedTo/QUICKSTART.md)** - Add API authorization
