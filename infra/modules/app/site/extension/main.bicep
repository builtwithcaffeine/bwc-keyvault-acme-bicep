@description('The name of the function app.')
param functionAppName string

@description('The zip content URL for released package.')
param packageUri string

resource oneDeploy 'Microsoft.Web/sites/extensions@2025-03-01' = {
  name: '${functionAppName}/onedeploy'
  properties: {
    packageUri: packageUri
    remoteBuild: false
  }
}
