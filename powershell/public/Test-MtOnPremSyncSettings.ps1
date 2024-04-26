<#
  .Synopsis
  Checks sensitive settings for On-Premises Synchronization

  .Description
  GET directory/onPremisesSynchronization

  .Example
  Test-MtOnPremSyncSettings -FeaturedId "blockSoftMatchEnabled"
#>

Function Test-OnPremSyncSettings {
  [OutputType([object])]

  param (

    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet("blockSoftMatchEnabled", "blockCloudObjectTakeoverThroughHardMatchEnabled")]
    [string[]]$FeatureId
  )

  $Result = (Invoke-MtGraphRequest -RelativeUri "directory/onPremisesSynchronization" -ApiVersion v1.0).features.$($FeatureId)
  return $Result

}