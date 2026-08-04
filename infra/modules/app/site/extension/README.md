# Site Extension OneDeploy `[Microsoft.Web/sites/extensions]`

This module deploys the OneDeploy site extension package to an existing function app.

You can reference the module as follows:

```bicep
module siteExtension 'modules/app/site/extension/main.bicep' = {
  name: 'deploy-function-app-package-weu'
  scope: resourceGroup(resourceGroupName)
  params: {
    functionAppName: functionAppName
    packageUri: 'https://github.com/polymind-inc/acmebot/releases/latest/download/acmebot.zip'
  }
}
```

For examples, please refer to the [Usage Examples](#usage-examples) section.

## Navigation

- [Resource Types](#resource-types)
- [Parameters](#parameters)
- [Outputs](#outputs)

## Resource Types

| Resource Type | API Version | References |
| :-- | :-- | :-- |
| `Microsoft.Web/sites/extensions` | 2025-03-01 | [AzAdvertizer](https://www.azadvertizer.net/azresourcetypes/microsoft.web_sites_extensions.html) · [Template reference](https://learn.microsoft.com/en-us/azure/templates/Microsoft.Web/2025-03-01/sites/extensions) |

## Parameters

### Required parameters

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`functionAppName`](#parameter-functionappname) | string | The name of the parent site resource. |
| [`packageUri`](#parameter-packageuri) | string | The ZIP package URI for the release artifact. |

### Optional parameters

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`extensionName`](#parameter-extensionname) | string | The name of the extension. |

### Parameter: `functionAppName`

The name of the parent site resource.

- Required: Yes
- Type: string

### Parameter: `packageUri`

The ZIP package URI for the release artifact.

- Required: Yes
- Type: string

### Parameter: `extensionName`

The name of the extension.

- Required: No
- Type: string
- Default: `'onedeploy'`
- Allowed:

  ```bicep
  [
    'onedeploy'
  ]
  ```

## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `name` | string | The name of the extension. |
| `resourceId` | string | The resource ID of the extension. |
| `resourceGroupName` | string | The resource group the extension was deployed into. |

## Usage Examples

```bicep
module deployFunctionAppPackage 'modules/app/site/extension/main.bicep' = {
  name: 'deploy-function-app-package-weu'
  scope: resourceGroup(resourceGroupName)
  params: {
    functionAppName: functionAppName
    packageUri: acmebotPackageUri
  }
}
```

## Notes

- Ensure the Function App exists before running this module.
- The extension deploys to `${functionAppName}/onedeploy` by default.
- If package deployment storage is private, ensure the function app identity and RBAC are configured correctly.

---

### Last updated

2026-08-04
