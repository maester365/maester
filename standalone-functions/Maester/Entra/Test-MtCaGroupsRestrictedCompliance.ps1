function Test-MtCaGroupsRestrictedCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaGroupsRestrictedCompliance
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
    $Policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -in @('enabled','enabledForReportingButNotEnforced') }

    $Groups = $Policies.conditions.users | Where-Object {
      @($_.includeGroups).Count -gt 0 -or @($_.excludeGroups).Count -gt 0
    } | ForEach-Object {
      $_.includeGroups + $_.excludeGroups
    } | Select-Object -Unique


    $GroupsDetail = foreach ($Group in $Groups) {
      try {
        Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/groups/$($Group)' | Select-Object displayName, isManagementRestricted, isAssignableToRole, id
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
      $ImpactedPolicies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.conditions.users.includeGroups -contains $UnrestrictedGroup.id -or $_.conditions.users.excludeGroups -contains $UnrestrictedGroup.id }

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
    return $result
  } catch {
    return $null
  }

}
