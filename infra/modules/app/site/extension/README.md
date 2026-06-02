# oneDeploy Bicep Module

Deploys a zip package to an Azure Function App using the `onedeploy` site extension.

## File

- `main.bicep`

## Parameters

- `functionAppName` (`string`): Name of the target Function App.
- `packageUri` (`string`): Publicly reachable URL to the deployment zip package.

## What it creates

- `Microsoft.Web/sites/extensions` resource:
  - Name: `${functionAppName}/onedeploy`
  - Properties:
    - `packageUri`
    - `remoteBuild: false`

## Usage example

```bicep
module deployFunctionAppPackage 'modules/app/site/extension/main.bicep' = {
  name: 'deploy-function-app-package-weu'
  scope: resourceGroup(resourceGroupName)
  params: {
    functionAppName: functionAppName
    packageUri: 'https://github.com/polymind-inc/acmebot/releases/latest/download/acmebot.zip'
  }
}
```

## Notes

- Ensure the Function App exists before running this module.
- If the Function App uses private storage for package deployment, make sure identity/RBAC is configured correctly.
