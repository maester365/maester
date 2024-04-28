<#
 .Synopsis
  Returns all the role definitions in the tenant.

 .Description

 .Example
  Get-MtRoles
#>

Function Get-MtRoles {
  [CmdletBinding()]
  param()

  Write-Verbose -Message "Getting directory role definitions."

  return Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion v1.0

}