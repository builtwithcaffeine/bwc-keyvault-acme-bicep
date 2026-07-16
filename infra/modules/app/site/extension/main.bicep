metadata name = 'Site Extension OneDeploy'
metadata description = 'This module deploys the OneDeploy site extension package to an existing function app.'

@description('Required. The name of the parent site resource.')
param functionAppName string

@description('Optional. The name of the extension.')
@allowed([
  'onedeploy'
])
param extensionName string = 'onedeploy'

@description('Required. The ZIP package URI for the release artifact.')
param packageUri string

resource app 'Microsoft.Web/sites@2025-03-01' existing = {
  name: functionAppName
}

resource oneDeploy 'Microsoft.Web/sites/extensions@2025-03-01' = {
  name: extensionName
  parent: app
  properties: {
    packageUri: packageUri
    remoteBuild: false
  }
}

@description('The name of the extension.')
output name string = oneDeploy.name

@description('The resource ID of the extension.')
output resourceId string = oneDeploy.id

@description('The resource group the extension was deployed into.')
output resourceGroupName string = resourceGroup().name
