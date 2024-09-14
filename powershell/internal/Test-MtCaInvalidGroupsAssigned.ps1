<#
  .Synopsis
  Checks if groups used in Conditional Access which are not exists anymore.

  .Description
  Security Groups will be used to exclude and include users from Conditional Access Policies.
  Assignments are still visible in the policy definition in Microsoft Graph API even the group is deleted.
  This test checks if all groups used in Conditional Access Policies are still exists and shows invalid or deleted items.

  .Example
  Test-MtCaInvalidGroupsAssigned

  .LINK
  https://maester.dev/docs/commands/Test-MtCaInvalidGroupsAssigned
#>

Function Test-MtCaInvalidGroupsAssigned {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  $Policies = Get-MtConditionalAccessPolicy

  $Groups = $Policies.conditions.users | Where-Object {
  @($_.includeGroups).Count -gt 0 -or @($_.excludeGroups).Count -gt 0
} | ForEach-Object {
  $_.includeGroups + $_.excludeGroups
} | Select-Object -Unique


$GroupsWhichNotExist = [System.Collections.Concurrent.ConcurrentDictionary[string]]::new()
$Groups | ForEach-Object -Parallel {
  $Group = $_
  $NotExistedGroup = $using:GroupsWhichNotExist
    $GraphQueryResult = Invoke-MtGraphRequest -RelativeUri "groups/$($Group)" -ApiVersion beta -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($GraphQueryResult)) {
      $NotExistedGroup.Add($Group) | Out-Null
    }
}

  $result = ($GroupsWhichNotExist | Measure-Object).Count -eq 0

  if ( $result ) {
    $ResultDescription = "Well done! All security groups with assignment in Conditional Access are protected!"
  } else {
    $ResultDescription = "These security groups with assignments in Conditional Access are exists anymore."
    $ImpactedCaGroups = "`n`n#### Impacted Conditional Access Policies`n`n | Security Group | Condition | Policy name | `n"
    $ImpactedCaGroups += "| --- | --- | --- |`n"
  }

  $InvalidGroupIds | ForEach-Object {
    $InvalidGroupId = $_
    $ImpactedPolicies = Get-MtConditionalAccessPolicy | Where-Object { $_.conditions.users.includeGroups -contains $InvalidGroupId -or $_.conditions.users.excludeGroups -contains $InvalidGroupId }
    foreach ($ImpactedPolicy in $ImpactedPolicies) {
      if ($ImpactedPolicy.conditions.users.includeGroups -contains $InvalidGroupId) {
        $Condition = "include"
      } elseif ($ImpactedPolicy.conditions.users.excludeGroups -contains $InvalidGroupId) {
        $Condition = "exclude"
      } else {
        $Condition = "Unknown"
      }
      $Policy = (Get-GraphObjectMarkdown -GraphObjects $ImpactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
      $Group = (Get-GraphObjectMarkdown -GraphObjects $GroupNotExists -GraphObjectType Groups -AsPlainTextLink)
      $ImpactedCaGroups += "| $($Group) | $($Condition) | $($Policy) | `n"
    }
  }

  $resultMarkdown = $ResultDescription + $ImpactedCaGroups
  Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown

  return $result
}