<#
 .Synopsis
  Returns all the conditional access policies in the tenant.

 .Description

 .Example
  Get-MtConditionalAccessPolicy
#>

Function Get-MtConditionalAccessPolicy {
  [CmdletBinding()]
  param()

  Write-Verbose -Message "Getting conditional access policies."

  # Note Graph v1.0 appears to return updates faster than beta
  return Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion v1.0

}