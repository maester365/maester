<#
  .Synopsis
  Checks if groups used in Conditional Access are protected by either Restricted Management Administrative Units or Role Assignable Groups. 

  .Description
  Microsoft recommends creating at least one conditional access policy targetting all cloud apps
  and ideally should be enabled for all users.

  Learn more:
  https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-restricted-management

  .Example
  Test-MtCaGroupsRestrictedByRmau

  Returns true if all Conditional Access groups are protected.

#>

Function Test-MtCaGroupsRestrictedByRmau {

  if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

  $Groups = $policies.conditions.users | Where-Object {
  @($_.includeGroups).Count -gt 0 -or @($_.excludeGroups).Count -gt 0
} | ForEach-Object {
  $_.includeGroups + $_.excludeGroups
} | Select-Object -Unique


  $GroupsDetail = foreach ($Group in $Groups) {
    Invoke-MtGraphRequest -RelativeUri "groups/$($Group)" -ApiVersion beta | Select-Object displayName, isManagementRestricted, isAssignableToRole, id
  }
  
  $UnrestrictedGroups = $GroupsDetail | Where-Object {
    -not $_.isManagementRestricted -and -not $_.isAssignableToRole
}

  $result = ($unrestrictedGroup | Measure-Object).Count -eq 0

  if ( $result ) {
    $ResultDescription = "Well done! All security groups with assignment in Conditional Access are protected!"
  } else {
    $ResultDescription = "These security groups with assignments in Conditional Access are not protected by Restricted Management Admin Units or Role Assignable groups."
    $ImpactedCaGroups = "`n`n#### Impacted Conditional Access Policies`n`n | Security Group | Condition | Policy name | `n"
    $ImpactedCaGroups += "| --- | --- | --- |`n"
  }

  foreach ($UnrestrictedGroup in $UnrestrictedGroups) {
    $ImpactedPolicies = Get-MtConditionalAccessPolicy | Where-Object { $_.conditions.users.includeGroups -contains $UnrestrictedGroup.id -or $_.conditions.users.excludeGroups -contains $UnrestrictedGroup.id }
    foreach ($ImpactedPolicy in $ImpactedPolicies) {
      if ($ImpactedPolicy.conditions.users.includeGroups -contains $UnrestrictedGroup.id) {
        $Condition = "include"
      } elseif ($ImpactedPolicy.conditions.users.excludeGroups -contains $UnrestrictedGroup.id) {
        $Condition = "exclude"
      } else {
        Write-Warning
        $Condition = "Unknown"
      }
      $Policy = (Get-GraphObjectMarkdown -GraphObjects $ImpactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
      $Group = (Get-GraphObjectMarkdown -GraphObjects $UnrestrictedGroup -GraphObjectType Groups -AsPlainTextLink)
      $ImpactedCaGroups += "| $($Group) | $($Condition) | $($Policy) | `n"
    }
  }

  $resultMarkdown = $ResultDescription + $ImpactedCaGroups
  Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown

  return $result
}