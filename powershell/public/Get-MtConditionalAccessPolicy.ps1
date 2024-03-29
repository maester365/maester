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
  return Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta

}