<#
  .Synopsis
  Checks if any conditional access policies include or exclude groups that have been deleted.

  .Description
  Security Groups will be used to exclude and include users from Conditional Access Policies.
  Assignments are still visible in the policy definition in Microsoft Graph API even the group is deleted.
  This test checks if all groups used in Conditional Access Policies still exist and shows invalid or deleted items.

  .Example
  Test-MtCaReferencedGroupsExist

  .LINK
  https://maester.dev/docs/commands/Test-MtCaReferencedGroupsExist
#>

Function Test-MtCaReferencedGroupsExist {
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  Write-Verbose "Running Test-MtCaReferencedGroupsExist"
  # Execute the test only when PowerShell Core and parallel processing is supported
  if ($PSVersionTable.PSEdition -eq 'Core') {

    $testDescription = "Invalid or deleted security groups are referenced in Conditional Access policies."
    # Get all policies (the state of policy does not have to be enabled)
    $Policies = Get-MtConditionalAccessPolicy

    $Groups = $Policies.conditions.users.includeGroups + $Policies.conditions.users.excludeGroups | Select-Object -Unique

    $GroupsWhichNotExist = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()

    $Groups | ForEach-Object { # Removed -Parallel as it caused errors
      try {
        $GraphErrorResult = $null
        $Group = $_
        Invoke-MtGraphRequest -RelativeUri "groups/$($Group)" -ApiVersion beta -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue | Out-Null
      }
      catch {
        if ($GraphErrorResult.Message -match "404 Not Found") {
          $GroupsWhichNotExist.Add($Group) | Out-Null
        }
      }
    }

    $result = ($GroupsWhichNotExist | Measure-Object).Count -eq 0

    if ( $result ) {
      $ResultDescription = "Well done! All Conditional Access policies are targeting active groups."
    } else {
      $ResultDescription = "These Conditional Access policies are referencing deleted security groups."
      $ImpactedCaGroups = "`n`n#### Impacted Conditional Access policies`n`n | Conditional Access policy | Deleted security group | Condition | `n"
      $ImpactedCaGroups += "| --- | --- | --- |`n"
    }

    $GroupsWhichNotExist | Sort-Object | ForEach-Object {
      $InvalidGroupId = $_
      # Get all policies (the state of policy does not have to be enabled)
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
        $ImpactedCaGroups += "| $($Policy) | $($InvalidGroupId) | $($Condition) | `n"
      }
    }
    $ImpactedCaGroups += "`n`nNote: Names are not available for deleted groups. If the group was deleted in the last 30 days it may be available under [Entra admin centre - Deleted groups](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/DeletedGroups/menuId/DeletedGroups).`n`n"

    $resultMarkdown = $ResultDescription + $ImpactedCaGroups
    Add-MtTestResultDetail -Description $testDescription -Result $resultMarkdown
    return $result

  } else {
    Write-Verbose "PowerShell Core not available, skip the test"
    # PowerShell Core not available, skip the test
    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Requires PowerShell 7.x or above. This test uses features that are not available in Windows PowerShell (5.x)."
    return $null
  }
}