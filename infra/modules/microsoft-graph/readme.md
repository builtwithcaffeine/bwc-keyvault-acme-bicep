# Microsoft Graph Bicep modules

This folder contains reusable Bicep modules for Microsoft Entra ID resources via the Microsoft Graph Bicep extension.

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (recommended: 0.44+)
- `microsoftGraphV1` extension alias configured in `bicepconfig.json`
- Microsoft Entra permissions required by each module operation

## Module map

```text
modules/microsoft-graph/
├── applications/
│   └── federatedIdentityCredentials/
├── appRoleAssignedTo/
├── groups/
├── oauth2PermissionGrants/
├── servicePrincipals/
└── users/
```

## Available modules

### `applications/`

Creates Microsoft Entra application registrations.

Typical outputs:

- `applicationId`
- `objectId`
- `resourceId`

### `applications/federatedIdentityCredentials/`

Creates federated identity credentials on existing applications.

Required inputs:

- `applicationId`
- `name`
- `issuer`
- `subject`
- `audiences`

### `servicePrincipals/`

Creates service principals for existing applications.

### `groups/`

Creates security or Microsoft 365 groups.

### `users/`

Resolves existing users by UPN for downstream references.

### `appRoleAssignedTo/`

Assigns app roles to users, groups, or service principals.

### `oauth2PermissionGrants/`

Creates delegated permission grants.

## Common composition pattern

```bicep
module app 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'app-registration'
  params: {
    displayName: 'Contoso App'
    appName: 'contoso-app'
  }
}

module sp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'app-sp'
  params: {
    appId: app.outputs.applicationId
  }
}

module oidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'app-github-oidc'
  params: {
    applicationId: app.outputs.objectId
    name: 'github-main'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:contoso/platform:ref:refs/heads/main'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    credentialDescription: 'GitHub Actions federation'
  }
}
```

## Notes

- Use least privilege for deployment identities.
- Prefer explicit, environment-scoped naming for reproducible deployments.
- For exact parameter/output contracts, use each module's `main.bicep` as the source of truth.

---

### Last updated

2026-08-04
