<#
 .Synopsis
  Returns all the role definitions in the tenant.

 .Description

 .Example
  Get-MtRole
#>

Function Get-MtRole {
  [CmdletBinding()]
  param()

  Write-Verbose -Message "Getting directory role definitions."

  return Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion v1.0

}