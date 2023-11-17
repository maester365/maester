<#
 .Synopsis
  Gets the default app mangement policy of the tenant.

 .Description
  GET /policies/defaultAppManagementPolicy

 .Example
  Test-MtAppManagementPolicyEnabled
#>

Function Test-MtAppManagementPolicyEnabled {
  [CmdletBinding()]
  param()

  $result = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/policies/defaultAppManagementPolicy"
  return $result.isEnabled -eq 'True'

}