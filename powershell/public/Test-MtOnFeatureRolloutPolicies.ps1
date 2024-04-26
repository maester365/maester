<#
  .Synopsis
  Checks configuration of feature roll out policies

  .Description
  GET policies/featureRolloutPolicies

  .Example
  Test-MtOnFeatureRolloutPolicies -FeaturedId "passthroughAuthentication"
#>

Function Test-MtOnFeatureRolloutPolicies {
  [OutputType([object])]

  param (
    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet("passthroughAuthentication", "seamlessSso")]
    [string[]]$FeatureId,
    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet("isEnabled", "isAppliedToOrganization")]
    [string[]]$Property
  )

  $Result = ((Invoke-MtGraphRequest -RelativeUri "policies/featureRolloutPolicies" -ApiVersion v1.0).value | Where-Object { $_.feature -eq $FeatureId }).$($Property)
  if ($null -eq $Result) {
    $Result = $false
  }
  return $Result

}