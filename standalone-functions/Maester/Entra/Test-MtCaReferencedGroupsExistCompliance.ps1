function Test-MtCaReferencedGroupsExistCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaReferencedGroupsExistCompliance
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
  Write-Verbose 'Running Test-MtCaReferencedGroupsExist'
  # Execute the test only when PowerShell Core and parallel processing is supported
  if ($PSVersionTable.PSEdition -ne 'Core') {
    Write-Verbose 'PowerShell Core not available, skip the test'
    # PowerShell Core not available, skip the test
    return $null
  }

  try {
    # Get all policies (the state of policy does not have to be enabled)
    $Policies = Get-MgIdentityConditionalAccessPolicy -All

    $Groups = $Policies.conditions.users.includeGroups + $Policies.conditions.users.excludeGroups | Select-Object -Unique

    $GroupsWhichNotExist = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()

    $Groups | ForEach-Object { # Removed -Parallel as it caused errors
      try {
        $GraphErrorResult = $null
        $Group = $_
        Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/groups/$($Group)' -ErrorVariable GraphErrorResult -ErrorAction SilentlyContinue | Out-Null
      } catch {
        if ($GraphErrorResult.Message -match '404 Not Found') {
          $GroupsWhichNotExist.Add($Group) | Out-Null
        }
      }
    }

    $result = ($GroupsWhichNotExist | Measure-Object).Count -eq 0
    if ( $result ) {
      $ResultDescription = 'Well done! All Conditional Access policies are targeting active groups.'
    } else {
      $ResultDescription = 'These Conditional Access policies are referencing deleted security groups.'
      $ImpactedCaGroups = "`n`n#### Impacted Conditional Access policies`n`n | Conditional Access policy | Deleted security group | Condition | `n"
      $ImpactedCaGroups += "| --- | --- | --- |`n"
    }

    $GroupsWhichNotExist | Sort-Object | ForEach-Object {
      $InvalidGroupId = $_
      # Get all policies (the state of policy does not have to be enabled)
      $ImpactedPolicies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.conditions.users.includeGroups -contains $InvalidGroupId -or $_.conditions.users.excludeGroups -contains $InvalidGroupId }
      foreach ($ImpactedPolicy in $ImpactedPolicies) {
        if ($ImpactedPolicy.conditions.users.includeGroups -contains $InvalidGroupId) {
          $Condition = 'include'
        } elseif ($ImpactedPolicy.conditions.users.excludeGroups -contains $InvalidGroupId) {
          $Condition = 'exclude'
        } else {
          $Condition = 'Unknown'
        }
        $Policy = (Get-GraphObjectMarkdown -GraphObjects $ImpactedPolicy -GraphObjectType ConditionalAccess -AsPlainTextLink)
        $ImpactedCaGroups += "| $($Policy) | $($InvalidGroupId) | $($Condition) | `n"
      }
    }
    $ImpactedCaGroups += "`n`nNote: Names are not available for deleted groups. If the group was deleted in the last 30 days it may be available under [Entra admin centre - Deleted groups](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/DeletedGroups/menuId/DeletedGroups).`n`n"

    $resultMarkdown = $ResultDescription + $ImpactedCaGroups
    return $result

  } catch {
    return $null
  }

}
