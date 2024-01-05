<#
 .Synopsis
  Returns all the conditional access policies in the tenant.

 .Description

 .Example
  Get-MtConditionalAccessPolicies
#>

Function Get-MtConditionalAccessPolicies {
  [CmdletBinding()]
  param(
    [switch]$Force
  )

  $uri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies'
  $result = Get-CacheValue $uri

  if (!$result -or $Force) {
    $result = Invoke-GraphRequest -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' -OutputType PSObject
    if ($result) {
      Set-CacheValue -Key $uri -Value $result
    }

  }

  return $result
}