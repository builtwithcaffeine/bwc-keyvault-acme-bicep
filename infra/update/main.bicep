targetScope = 'resourceGroup'

@description('Name of the existing Acmebot Function App to update.')
@minLength(1)
param functionAppName string

@description('Acmebot release tag to deploy. Use latest, 5.0.0, or v5.0.0.')
@minLength(1)
param acmebotReleaseTag string = 'latest'

var normalizedReleaseTag = startsWith(toLower(acmebotReleaseTag), 'v')
  ? acmebotReleaseTag
  : 'v${acmebotReleaseTag}'

var releaseTag = toLower(acmebotReleaseTag) == 'latest'
  ? 'latest'
  : normalizedReleaseTag

#disable-next-line no-hardcoded-env-urls
var appPackageUri = 'https://github.com/polymind-inc/acmebot/releases/download/${releaseTag}/acmebot.zip'

module deployFunctionAppPackage '../modules/app/site/extension/main.bicep' = {
  scope: resourceGroup()
  params: {
    functionAppName: functionAppName
    packageUri: appPackageUri
  }
}

output functionAppName string = functionAppName
output acmebotReleaseTag string = acmebotReleaseTag
output releaseTag string = releaseTag
output appPackageUri string = appPackageUri
output extensionName string = deployFunctionAppPackage.outputs.name
output extensionResourceId string = deployFunctionAppPackage.outputs.resourceId
