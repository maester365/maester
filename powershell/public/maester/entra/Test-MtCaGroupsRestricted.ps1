<#
  .Synopsis
  Checks if groups used in Conditional Access are protected by either Restricted Management Administrative Units or Role Assignable Groups.

  .Description
  Security Groups will be used to exclude and include users from Conditional Access Policies.
  Modify group membership outside of Conditional Access Administrator or other privileged roles can lead to bypassing Conditional Access Policies.
  To prevent this, you can protect these groups by using Restricted Management Administrative Units or Role Assignable Groups.
  Role Assignable Group should be used in combination of assignments to Entra ID roles. Restricted Management Administrative Units should be used to protect groups by restricting management to specific users or groups.
  This test checks if all groups used in Conditional Access Policies are protected.

  Learn more:
  https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-restricted-management

  .Example
  Test-MtCaGroupsRestricted

  .LINK
  https://maester.dev/docs/commands/Test-MtCaGroupsRestricted
#>

function Test-MtCaGroupsRestricted {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  try {
    $Policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

    $Groups = $Policies.conditions.users | Where-Object {
      @($_.includeGroups).Count -gt 0 -or @($_.excludeGroups).Count -gt 0
    } | ForEach-Object {
      $_.includeGroups + $_.excludeGroups
    } | Select-Object -Unique


    $GroupsDetail = foreach ($Group in $Groups) {
      try {
        Invoke-MtGraphRequest -RelativeUri "groups/$($Group)" -ApiVersion beta | Select-Object displayName, isManagementRestricted, isAssignableToRole, id
      } catch {
        Write-Verbose "Group $Group not found"
      }
    }

    $UnrestrictedGroups = $GroupsDetail | Where-Object {
      -not $_.isManagementRestricted -and -not $_.isAssignableToRole
    }

    $result = ($UnrestrictedGroups | Measure-Object).Count -eq 0

    if ( $result ) {
      $ResultDescription = 'Well done! All security groups with assignment in Conditional Access are protected.'
    } else {
      $ResultDescription = 'These security groups with assignments in Conditional Access are not protected by Restricted Management Admin Units or Role Assignable groups.'
      $ImpactedCaGroups = "`n`n#### Impacted Conditional Access Policies`n`n | Security Group | Condition | Policy name | `n"
      $ImpactedCaGroups += "| --- | --- | --- |`n"
    }

    foreach ($UnrestrictedGroup in $UnrestrictedGroups) {
      # Get all policies (the state of policy does not have to be enabled)
      $ImpactedPolicies = Get-MtConditionalAccessPolicy | Where-Object { $_.conditions.users.includeGroups -contains $UnrestrictedGroup.id -or $_.conditions.users.excludeGroups -contains $UnrestrictedGroup.id }

      foreach ($ImpactedPolicy in $ImpactedPolicies) {
        if ($ImpactedPolicy.conditions.users.includeGroups -contains $UnrestrictedGroup.id) {
          $Condition = 'include'
        } elseif ($ImpactedPolicy.conditions.users.excludeGroups -contains $UnrestrictedGroup.id) {
          $Condition = 'exclude'
        } else {
          $Condition = 'Unknown'
        }
        $Policy = (Get-GraphObjectMarkdown -GraphObjects $ImpactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
        $Group = (Get-GraphObjectMarkdown -GraphObjects $UnrestrictedGroup -GraphObjectType Groups -AsPlainTextLink)
        $ImpactedCaGroups += "| $($Group) | $($Condition) | $($Policy) | `n"
      }
    }

    $resultMarkdown = $ResultDescription + $ImpactedCaGroups
    Add-MtTestResultDetail -Result $resultMarkdown
    return $result
  } catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
  }
}
