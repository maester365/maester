<#
 .Synopsis
  Checks if the default app management policy is enabled.

 .Description
  GET /policies/defaultAppManagementPolicy

 .Example
  Test-MtAppManagementPolicyEnabled
#>

Function Test-MtAppManagementPolicyEnabled {
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  $result = Invoke-MtGraphRequest -RelativeUri "policies/defaultAppManagementPolicy"
  return $result.isEnabled -eq 'True'

}