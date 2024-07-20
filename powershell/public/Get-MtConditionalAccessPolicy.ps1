<#
 .Synopsis
  Returns all the conditional access policies in the tenant.

 .Description

 .Example
  Get-MtConditionalAccessPolicy

.LINK
    https://maester.dev/docs/commands/Get-MtConditionalAccessPolicy
#>
function Get-MtConditionalAccessPolicy {
  [CmdletBinding()]
  param()

  Write-Verbose -Message "Getting conditional access policies."

  return Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/policies' -ApiVersion beta

}