<#
  .Synopsis
  Checks if groups used in Conditional Access which are not exists anymore.

  .Description
  Security Groups will be used to exclude and include users from Conditional Access Policies.
  Assignments are still visible in the policy definition in Microsoft Graph API even the group is deleted.
  This test checks if all groups used in Conditional Access Policies still exist and shows invalid or deleted items.

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

  # Execute the test only when PowerShell Core and parallel processing is supported
  if ($PSVersionTable.PSEdition -eq 'Core') {

    $testDescription = "Conditional Access Policies should not target to security groups which are not exists anymore."
    $Policies = Get-MtConditionalAccessPolicy

    $Groups = $Policies.conditions.users.includeGroups + $Policies.conditions.users.excludeGroups |  Select-Object -Unique

    if ($Groups.Count -lt 50) {
      $GroupsWhichNotExist = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
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
        $ResultDescription = "Well done! All security groups with active assignments in Conditional Access are protected!"
      } else {
        $ResultDescription = "The security groups with active assignments in Conditional Access do not exist anymore. Invalid groups are only visible in the policy assignment in Microsoft Graph API and not in the Portal UI."
        $ImpactedCaGroups = "`n`n#### Impacted Conditional Access Policies`n`n | Security Group | Condition | Policy name | `n"
        $ImpactedCaGroups += "| --- | --- | --- |`n"
      }

      $GroupsWhichNotExist  | Sort-Object | ForEach-Object {
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
          $ImpactedCaGroups += "| $($InvalidGroupId) | $($Condition) | $($Policy) | `n"
        }
      }

      $resultMarkdown = $ResultDescription + $ImpactedCaGroups
      Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown
      return $result
    } else {
      # Too many groups to check, skip the test because of performance reasons
      Add-MtTestResultDetail -SkippedBecause unsupported
      return $null
    }
  } else {
    # PowerShell Core not available, skip the test
    Add-MtTestResultDetail -SkippedBecause NotSupported
    return $null
  }
}