# Microsoft Graph Federated Identity Credentials Module

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep Version](https://img.shields.io/badge/Bicep-v0.24+-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

> **Enterprise Bicep module for configuring Federated Identity Credentials in Azure AD applications using Microsoft Graph Bicep extension v1.0**

## 🚀 Overview

This enterprise-grade Bicep module provides comprehensive configuration capabilities for **Federated Identity Credentials** in Azure Active Directory applications. It enables secure, passwordless authentication for external systems using **OpenID Connect (OIDC)** federation, eliminating the need for application secrets and certificates.

### Key Features

- ✅ **Passwordless Authentication**: Eliminate secrets and certificates with OIDC federation
- ✅ **Multiple Provider Support**: GitHub Actions, Azure DevOps, AWS IAM, Google Cloud, GitLab
- ✅ **Enterprise Security**: Zero-trust authentication patterns and secure CI/CD workflows
- ✅ **Workload Identity**: Support for Azure Kubernetes Service (AKS) workload identity
- ✅ **Multi-Environment**: Development, staging, and production environment patterns
- ✅ **Comprehensive Validation**: Parameter validation and security best practices
- ✅ **Rich Documentation**: Extensive examples and troubleshooting guidance

### Use Cases

- **CI/CD Pipelines**: Secure authentication for GitHub Actions, Azure DevOps, and other CI/CD systems
- **Multi-Cloud Integration**: Federated access between Azure, AWS, and Google Cloud Platform
- **Kubernetes Workloads**: AKS workload identity for pod-level authentication
- **Third-Party Applications**: External application integration without credential management
- **Microservices Architecture**: Service-to-service authentication in distributed systems

## 📋 Prerequisites

- Azure subscription with appropriate permissions
- Microsoft Graph Bicep extension v1.0 or later
- Azure CLI 2.50+ or Azure PowerShell 10.0+
- **Parent Azure AD Application** (must exist - this module creates credentials for existing applications)

## 🔧 Parameters

### Required Parameters

| Parameter | Type | Description | Examples |
|-----------|------|-------------|----------|
| `applicationId` | `string` | **Resource ID of the existing Azure AD application** | From parent application module |
| `name` | `string` | **Unique name for the federated identity credential** | `github-main-branch`, `azdo-prod-deploy` |
| `issuer` | `string` | **OIDC issuer URL of the external identity provider** | See [Common Issuers](#common-issuers) |
| `subject` | `string` | **Subject claim pattern from incoming tokens** | See [Subject Patterns](#subject-patterns) |
| `audiences` | `array` | **List of valid audiences for token validation** | `['api://AzureADTokenExchange']` |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `credentialDescription` | `string` | `''` | Human-readable description of the credential's purpose |

### Common Issuers

| Provider | Issuer URL | Use Case |
|----------|------------|----------|
| **GitHub Actions** | `https://token.actions.githubusercontent.com` | CI/CD workflows |
| **Azure DevOps** | `https://vstoken.dev.azure.com/{organization}` | Azure Pipelines |
| **Google Cloud** | `https://accounts.google.com` | GCP service accounts |
| **AWS IAM** | `arn:aws:iam::{account}:oidc-provider/token.actions.githubusercontent.com` | Cross-cloud federation |
| **GitLab** | `https://gitlab.com` | GitLab CI/CD |
| **AKS Workload Identity** | `https://oidc.prod-aks.azure.com/{tenant_id}` | Kubernetes workloads |

### Subject Patterns

#### GitHub Actions Patterns
```javascript
// Branch-specific access
"repo:owner/repository:ref:refs/heads/main"
"repo:owner/repository:ref:refs/heads/develop"

// Environment-specific access
"repo:owner/repository:environment:production"
"repo:owner/repository:environment:staging"

// Pull request access
"repo:owner/repository:pull_request"

// Tag-based deployment
"repo:owner/repository:ref:refs/tags/v*"

// Multiple branch pattern (requires wildcards in some systems)
"repo:owner/repository:ref:refs/heads/*"
```

#### Azure DevOps Patterns
```javascript
// Service connection pattern
"sc://organization/project/serviceconnection"

// Build pipeline pattern
"build://organization/project/pipeline"

// Environment-specific pipeline
"sc://myorg/myproject/prod-deployment"
```

#### AKS Workload Identity Patterns
```javascript
// Specific namespace and service account
"system:serviceaccount:namespace:serviceaccount-name"

// Multiple environments
"system:serviceaccount:production:app-serviceaccount"
"system:serviceaccount:staging:app-serviceaccount"
```

## 📤 Outputs

| Output | Type | Description |
|--------|------|-------------|
| `resourceId` | `string` | Full resource ID of the federated identity credential |
| `name` | `string` | Name of the credential |
| `issuer` | `string` | Configured issuer URL |
| `subject` | `string` | Configured subject pattern |
| `audiences` | `array` | List of valid audiences |
| `credentialDescription` | `string` | Description of the credential |

## 🎯 Usage Examples

### Example 1: GitHub Actions CI/CD

```bicep
// Deploy federated identity for GitHub Actions main branch
module githubMainCredential '../main.bicep' = {
  name: 'github-main-branch-credential'
  params: {
    applicationId: myApplication.outputs.resourceId
    name: 'github-main-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorganization/myrepository:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions authentication for main branch deployments to production'
  }
}

// Deploy federated identity for GitHub Actions develop branch
module githubDevCredential '../main.bicep' = {
  name: 'github-dev-branch-credential'
  params: {
    applicationId: myApplication.outputs.resourceId
    name: 'github-develop-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorganization/myrepository:ref:refs/heads/develop'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions authentication for develop branch deployments to staging'
  }
}
```

### Example 2: Multi-Environment Azure DevOps

```bicep
// Production environment credential
module azdoProdCredential '../main.bicep' = {
  name: 'azdo-production-credential'
  params: {
    applicationId: productionApp.outputs.resourceId
    name: 'azdo-production-deployment'
    issuer: 'https://vstoken.dev.azure.com/myorganization'
    subject: 'sc://myorganization/myproject/production-serviceconnection'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Azure DevOps service connection for production environment deployments'
  }
}

// Staging environment credential
module azdoStagingCredential '../main.bicep' = {
  name: 'azdo-staging-credential'
  params: {
    applicationId: stagingApp.outputs.resourceId
    name: 'azdo-staging-deployment'
    issuer: 'https://vstoken.dev.azure.com/myorganization'
    subject: 'sc://myorganization/myproject/staging-serviceconnection'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Azure DevOps service connection for staging environment deployments'
  }
}
```

### Example 3: AKS Workload Identity

```bicep
// AKS workload identity for production namespace
module aksWorkloadCredential '../main.bicep' = {
  name: 'aks-workload-identity'
  params: {
    applicationId: aksApplication.outputs.resourceId
    name: 'aks-production-workload'
    issuer: 'https://oidc.prod-aks.azure.com/${tenant().tenantId}'
    subject: 'system:serviceaccount:production:backend-service'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'AKS workload identity for backend service in production namespace'
  }
}
```

### Example 4: Multi-Cloud Federation (AWS Integration)

```bicep
// AWS cross-cloud federation
module awsFederationCredential '../main.bicep' = {
  name: 'aws-cross-cloud-credential'
  params: {
    applicationId: crossCloudApp.outputs.resourceId
    name: 'aws-github-federation'
    issuer: 'arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com'
    subject: 'repo:myorganization/aws-integration:ref:refs/heads/main'
    audiences: [
      'sts.amazonaws.com'
      'api://AzureADTokenExchange'
    ]
    credentialDescription: 'Cross-cloud federation between Azure and AWS via GitHub Actions'
  }
}
```

### Example 5: Environment-Specific GitHub Actions

```bicep
// Array of environments for dynamic deployment
var environments = [
  {
    name: 'development'
    branch: 'develop'
    description: 'Development environment for feature testing'
  }
  {
    name: 'staging'
    branch: 'staging'
    description: 'Staging environment for pre-production validation'
  }
  {
    name: 'production'
    branch: 'main'
    description: 'Production environment for live services'
  }
]

// Deploy credentials for each environment
module environmentCredentials '../main.bicep' = [for env in environments: {
  name: 'github-${env.name}-credential'
  params: {
    applicationId: applications[env.name].outputs.resourceId
    name: 'github-${env.name}-${env.branch}'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorganization/myrepository:ref:refs/heads/${env.branch}'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: '${env.description} - GitHub Actions authentication'
  }
}]
```

### Example 6: GitLab CI/CD Integration

```bicep
// GitLab CI/CD federated identity
module gitlabCredential '../main.bicep' = {
  name: 'gitlab-cicd-credential'
  params: {
    applicationId: gitlabApp.outputs.resourceId
    name: 'gitlab-main-branch'
    issuer: 'https://gitlab.com'
    subject: 'project_path:mygroup/myproject:ref_type:branch:ref:main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitLab CI/CD authentication for main branch deployments'
  }
}
```

### Example 7: Pull Request Validation

```bicep
// GitHub Actions pull request validation
module githubPRCredential '../main.bicep' = {
  name: 'github-pr-validation'
  params: {
    applicationId: validationApp.outputs.resourceId
    name: 'github-pull-request'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorganization/myrepository:pull_request'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'GitHub Actions authentication for pull request validation and testing'
  }
}
```

### Example 8: Conditional Deployment by Environment

```bicep
@allowed(['development', 'staging', 'production'])
param environmentType string

// Conditional credential creation based on environment
module conditionalCredential '../main.bicep' = if (environmentType == 'production') {
  name: 'production-only-credential'
  params: {
    applicationId: productionApp.outputs.resourceId
    name: 'production-secure-deployment'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorganization/myrepository:environment:production'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Production-only deployment credential with enhanced security'
  }
}
```

## 🏢 Enterprise Patterns

### Pattern 1: Team-Based Access Control

```bicep
// Development team access
module devTeamCredential '../main.bicep' = {
  name: 'dev-team-access'
  params: {
    applicationId: devApplication.outputs.resourceId
    name: 'dev-team-github'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:enterprise/dev-services:ref:refs/heads/develop'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Development team access for feature development and testing'
  }
}

// Operations team access
module opsTeamCredential '../main.bicep' = {
  name: 'ops-team-access'
  params: {
    applicationId: opsApplication.outputs.resourceId
    name: 'ops-team-deployment'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:enterprise/ops-infrastructure:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Operations team access for infrastructure management and deployments'
  }
}
```

### Pattern 2: Microservices Architecture

```bicep
// Individual service credentials
var services = [
  'user-service'
  'order-service'
  'payment-service'
  'notification-service'
]

module serviceCredentials '../main.bicep' = [for service in services: {
  name: '${service}-credential'
  params: {
    applicationId: serviceApplications[service].outputs.resourceId
    name: '${service}-github-deployment'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:enterprise/${service}:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Federated identity for ${service} microservice deployment and authentication'
  }
}]
```

### Pattern 3: Multi-Tenant SaaS Application

```bicep
// Tenant-specific credentials
var tenants = [
  {
    name: 'tenant-alpha'
    repository: 'saas-tenant-alpha'
    environment: 'production'
  }
  {
    name: 'tenant-beta' 
    repository: 'saas-tenant-beta'
    environment: 'production'
  }
]

module tenantCredentials '../main.bicep' = [for tenant in tenants: {
  name: '${tenant.name}-credential'
  params: {
    applicationId: tenantApplications[tenant.name].outputs.resourceId
    name: '${tenant.name}-deployment'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:enterprise/${tenant.repository}:environment:${tenant.environment}'
    audiences: ['api://AzureADTokenExchange']
    credentialDescription: 'Tenant-specific federated identity for ${tenant.name} SaaS deployment'
  }
}]
```

## 🔒 Security Best Practices

### 1. Subject Claim Specificity
- **Use specific subject patterns** - avoid wildcards where possible
- **Environment-based subjects** for production deployments
- **Branch protection** with specific branch references

### 2. Audience Validation
- **Always specify audiences** - never rely on defaults in production
- **Use standard audience** `api://AzureADTokenExchange` for Azure
- **Multi-cloud audiences** only when necessary

### 3. Credential Lifecycle Management
- **Regular rotation** of federated credentials
- **Monitoring and auditing** of credential usage
- **Principle of least privilege** in subject patterns

### 4. Environment Isolation
- **Separate applications** for different environments
- **Environment-specific credentials** to prevent cross-contamination
- **Conditional deployment** based on environment type

## 🔍 Troubleshooting

### Common Issues

#### Issue 1: Authentication Failures
**Symptoms**: `AADSTS70021: No matching federated identity record found`

**Solutions**:
- Verify subject claim matches exactly (case-sensitive)
- Check issuer URL is correct and accessible
- Ensure audiences include required values
- Confirm credential name is unique within the application

#### Issue 2: Subject Pattern Mismatches
**Symptoms**: Token validation failures in CI/CD

**Solutions**:
```bicep
// ❌ Incorrect - missing organization
subject: 'repo:myrepository:ref:refs/heads/main'

// ✅ Correct - includes organization
subject: 'repo:myorganization/myrepository:ref:refs/heads/main'
```

#### Issue 3: Audience Configuration
**Symptoms**: `AADSTS50013: Assertion audience is invalid`

**Solutions**:
```bicep
// ❌ Incorrect - missing required audience
audiences: ['custom://audience']

// ✅ Correct - includes standard token exchange audience
audiences: ['api://AzureADTokenExchange']
```

### Debugging Commands

```bash
# Verify application exists
az ad app list --display-name "MyApplication" --query "[].{id:id,displayName:displayName}"

# List federated credentials for application
az ad app federated-credential list --id <application-id>

# Test token acquisition (GitHub Actions)
curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
     "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange"
```

### Validation Scripts

```bash
#!/bin/bash
# validate-federation.sh

APPLICATION_ID="$1"
CREDENTIAL_NAME="$2"

if [ -z "$APPLICATION_ID" ] || [ -z "$CREDENTIAL_NAME" ]; then
    echo "Usage: $0 <application-id> <credential-name>"
    exit 1
fi

echo "Validating federated identity credential..."
az ad app federated-credential show \
    --id "$APPLICATION_ID" \
    --federated-credential-id "$CREDENTIAL_NAME" \
    --query "{name:name,issuer:issuer,subject:subject,audiences:audiences}"
```

## 📚 Related Documentation

- [Microsoft Graph Applications Module](../README.md)
- [Azure AD Workload Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [GitHub Actions OIDC Integration](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure DevOps Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure)
- [AKS Workload Identity](https://docs.microsoft.com/en-us/azure/aks/workload-identity-overview)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](../../../../../CONTRIBUTING.md) for details.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](../../../../../LICENSE) file for details.

---

**Built with ❤️ by the Platform Engineering Team**

> 💡 **Need Help?** Check our [Troubleshooting Guide](#troubleshooting) or open an issue in our repository.