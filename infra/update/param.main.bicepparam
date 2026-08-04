using './main.bicep'

// Existing Acmebot Function App.
param functionAppName = 'func-bwc-kvacme-dev-weu'

// Deploy the latest GitHub release asset by default.
// Set this to 'latest', '5.0.0', or 'v5.0.0' when you want to pin a release.
param acmebotReleaseTag = 'latest'
