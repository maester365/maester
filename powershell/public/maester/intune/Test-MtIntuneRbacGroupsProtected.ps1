<#
  .Synopsis
  Checks if Intune RBAC groups are protected by Restricted Management Administrative Units or Role Assignable Groups.

  .Description
  This command checks if the security groups assigned in Intune RBAC roles are protected by Restricted Management Administrative Units or Role Assignable Groups.
  This is important to ensure that only authorized administrators can manage specific devices or users, enhancing the security of your Intune environment.

  .Example
  Test-MtIntuneRbacGroupsProtected

  .LINK
  https://maester.dev/docs/commands/Test-MtIntuneRbacGroupsProtected
#>

function Test-MtIntuneRbacGroupsProtected {
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  if (-not (Get-MtLicenseInformation -Product Intune)) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
    return $null
  }

  try {
    Write-Verbose 'Retrieving Intune RBAC role definitions and assignments...'
    # Help Desk Operator: 9e0cc482-82df-4ab2-a24c-0c23a3f52e1e
    $roleDefinitions = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/roleDefinitions' -ApiVersion beta

    $roleAssignmentsExpanded = foreach ($definition in $roleDefinitions) {
      $roleAssignments = @(Invoke-MtGraphRequest -RelativeUri "deviceManagement/roleDefinitions/$($definition.id)/roleAssignments" -ApiVersion beta)
      foreach ($assignment in $roleAssignments.value) {
        $assignmentDetails = Invoke-MtGraphRequest -RelativeUri "deviceManagement/roleAssignments/$($assignment.id)" -ApiVersion beta
        foreach ($memberId in $assignmentDetails.members) {

          try {
            $groupInfo = Invoke-MtGraphRequest -RelativeUri "groups/$memberId" -Select 'displayName, isManagementRestricted, isAssignableToRole, id' -ApiVersion beta

            [PSCustomObject]@{
              RoleDefinitionName     = $definition.displayName
              GroupId                = $memberId
              GroupDisplayName       = $groupInfo.displayName
              IsManagementRestricted = [bool]$groupInfo.isManagementRestricted
              IsAssignableToRole     = [bool]$groupInfo.isAssignableToRole
            }
          } catch {
            Write-Verbose "Group with id: $memberId not found"
          }
        }
      }
    }

    $unprotectedGroups = @($roleAssignmentsExpanded | Where-Object { -not ($_.isManagementRestricted -or $_.isAssignableToRole) } | Select-Object -Unique)

    $ResultDescription = ''
    if ($unprotectedGroups.Count -eq 0) {
      $ResultDescription = 'All security groups with Intune RBAC role assignments are protected.'
    } else {
      $ResultDescription = "These security groups with Intune RBAC role assignments are not protected by Restricted Management Administrative Units or Role Assignable groups:`n"
      $ResultDescription += "| RoleDefinitionName | GroupId | GroupDisplayName | IsManagementRestricted | IsAssignableToRole |`n"
      $ResultDescription += "| --- | --- | --- | --- | --- |`n"
      foreach ($group in $unprotectedGroups) {
        $ResultDescription += "| $($group.RoleDefinitionName) | $($group.GroupId) | $($group.GroupDisplayName) | $($group.IsManagementRestricted) | $($group.IsAssignableToRole) | `n"
      }
    }

    Add-MtTestResultDetail -Result $ResultDescription
    return $unprotectedGroups.Count -eq 0
  } catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
  }
}
