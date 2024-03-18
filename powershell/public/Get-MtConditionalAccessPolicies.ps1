<#
 .Synopsis
  Returns all the conditional access policies in the tenant.

 .Description

 .Example
  Get-MtConditionalAccessPolicies
#>

Function Get-MtConditionalAccessPolicies {
  [CmdletBinding()]
  param()

  return Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta

}