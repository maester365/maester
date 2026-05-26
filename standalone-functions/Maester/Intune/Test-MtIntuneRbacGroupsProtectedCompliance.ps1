function Test-MtIntuneRbacGroupsProtectedCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtIntuneRbacGroupsProtectedCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation


  try {
    Write-Verbose 'Retrieving Intune RBAC role definitions and assignments...'
    # Help Desk Operator: 9e0cc482-82df-4ab2-a24c-0c23a3f52e1e
    $roleDefinitions = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/roleDefinitions'

    $roleAssignmentsExpanded = foreach ($definition in $roleDefinitions) {
      $roleAssignments = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/roleDefinitions/$($definition.id)/roleAssignments')
      foreach ($assignment in $roleAssignments.value) {
        $assignmentDetails = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/roleAssignments/$($assignment.id)'
        foreach ($memberId in $assignmentDetails.members) {

          try {
            $groupInfo = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/groups/$memberId' -Select 'displayName, isManagementRestricted, isAssignableToRole, id' -ApiVersion beta

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

    return $unprotectedGroups.Count -eq 0
  } catch {
    return $null
  }

}
