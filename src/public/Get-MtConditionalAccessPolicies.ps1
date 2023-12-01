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

  $result = Invoke-GraphRequest -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -OutputType PSObject
  return $result
}