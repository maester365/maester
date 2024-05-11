<#
 .Synopsis
  Returns all the role definitions in the tenant.

 .Description

 .Example
  Get-MtRole
#>

Function Get-MtRole {
  [CmdletBinding()]
  param(
    [switch]$CisaHighlyPrivilegedRoles
  )

  #https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#highly-privileged-roles
  $highlyPrivilegedRoles = @(
    "Global Administrator",
    "Privileged Role Administrator",
    "User Administrator",
    "SharePoint Administrator",
    "Exchange Administrator",
    "Hybrid Identity Administrator",
    "Application Administrator",
    "Cloud Application Administrator"
  )

  Write-Verbose -Message "Getting directory role definitions."

  $roles = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion v1.0

  if ($CisaHighlyPrivilegedRoles){
    return $roles | Where-Object {`
      $_.displayName -in $highlyPrivilegedRoles
    }
  }

  return $roles
}