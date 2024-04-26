<#
  .Synopsis
  Checks settings of On-Premises Publishing Profiles (Authentication Agents)

  .Description
  GET onPremisesPublishingProfiles/authentication

  .Example
  Test-MtOnPremPublishingProfiles -Property "ActiveAgents"
#>

Function Test-MtOnPremPublishingProfiles {
  [OutputType([object])]

  param (
    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet("ActiveAgents")]
    [string[]]$Property
  )

  if ($Property -eq "ActiveAgents") {
    $ProfileProperty = (Invoke-MtGraphRequest -RelativeUri "onPremisesPublishingProfiles/authentication/agentGroups?`$expand=agents" -ApiVersion beta -OutputType PSObject)
    $Result = $ProfileProperty.agents.status -contains "Active"
  }
  return $Result
}