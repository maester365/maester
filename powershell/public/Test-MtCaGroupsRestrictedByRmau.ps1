<#
  .Synopsis
  Checks if the tenant has at least one fallback policy targetting All Apps and All Users.

  .Description
  Microsoft recommends creating at least one conditional access policy targetting all cloud apps
  and ideally should be enabled for all users.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access#apply-conditional-access-policies-to-every-app

  .Example
  Test-MtCaAllAppsExists

  Returns true if at least one conditional access policy exists that targets all cloud apps and all users.

  .Example
  Test-MtCaAllAppsExists -SkipCheckAllUsers

  Returns true if at least one conditional access policy exists that targets all cloud apps and all users, but skips the check for all users.
#>

Function Test-MtCaGroupsRestrictedByRmau {

  if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
  $Groups = $policies.conditions.users | Where-Object {$_.includeGroups -ne ""} | Select-Object -ExpandProperty includeGroups | Select-Object -unique
  $GroupsDetail = foreach ($Group in $Groups) {
    Invoke-MtGraphRequest -RelativeUri "groups/$($Group)" -ApiVersion beta | Select-Object displayName, isManagementRestricted, id
  }
  $UnrestrictedGroups = $GroupsDetail | Where-Object {$_.isManagementRestricted -eq $true} # Filtering out groups that are created as role assignable group
  $result = ($unrestrictedGroup | Measure-Object).Count -eq 0

  if ( $result ) {
    $ResultDescription = "All security groups with assignment in Conditional Access are protected."
  } else {
    $ResultDescription = "These security groups with assignments in Conditional Access are not protected by RMAU."
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