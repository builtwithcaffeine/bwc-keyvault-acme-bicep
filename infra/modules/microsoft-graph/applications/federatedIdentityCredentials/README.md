# Microsoft Graph federated identity credentials module

Creates a federated identity credential on an existing Microsoft Entra application using the Microsoft Graph Bicep extension.

## What this module does

- Adds one `federatedIdentityCredentials` resource to an existing application.
- Enables passwordless OIDC trust for CI/CD or workload identity scenarios.

## Prerequisites

- Bicep CLI installed (`az bicep version`)
- `microsoftGraphV1` extension alias configured in `bicepconfig.json`
- Microsoft Entra role with permission to manage applications
- Existing parent application identifier (`applicationId` input)

## Parameters

### Required

- `applicationId` (`string`): parent application identifier used in the Graph resource path
- `name` (`string`): federated credential name (unique per application)
- `issuer` (`string`): OIDC issuer URL
- `subject` (`string`): expected subject claim pattern
- `audiences` (`array`): allowed audiences (at least one)

### Optional

- `credentialDescription` (`string`, default `''`): human-readable description

## Outputs

- `resourceId`
- `name`
- `issuer`
- `subject`
- `audiences`
- `credentialDescription`

## Example

```bicep
module githubOidc 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'github-main-oidc'
  params: {
    applicationId: app.outputs.objectId
    name: 'github-main-branch'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:contoso/platform:ref:refs/heads/main'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    credentialDescription: 'GitHub Actions OIDC for main branch deployments'
  }
}
```

## Common issuer examples

- GitHub Actions: `https://token.actions.githubusercontent.com`
- Azure DevOps: `https://vstoken.dev.azure.com/{organization}`
- GitLab: `https://gitlab.com`

## Troubleshooting

- `AADSTS70021` (no matching federated identity): verify `issuer` + `subject` exact match (case-sensitive).
- `AADSTS700224` (invalid audience): ensure workflow requests the same audience configured in `audiences`.

## Related docs

- `QUICKSTART.md`
- `../README.md` (applications module)
- `../../readme.md` (module index)

---

*Last updated: 2026-07-16*
