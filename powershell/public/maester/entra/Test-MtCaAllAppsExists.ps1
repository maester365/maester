function Test-MtCaAllAppsExists {
    <#
    .Synopsis
    Checks if the tenant has at least one fallback policy targeting All Apps and All Users.

    .Description
    Microsoft recommends creating at least one Conditional Access policy targeting all cloud apps
    and ideally should be enabled for all users.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access#apply-conditional-access-policies-to-every-app

    .Example
    Test-MtCaAllAppsExists

    Returns true if at least one Conditional Access policy exists that targets all cloud apps and all users.

    .Example
    Test-MtCaAllAppsExists -SkipCheckAllUsers

    Returns true if at least one Conditional Access policy exists that targets all cloud apps; the check for all users is skipped.

    .LINK
    https://maester.dev/docs/commands/Test-MtCaAllAppsExists
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plurality')]
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Position = 0)]
    # Do not check for All Users target in policy.
    [switch] $SkipCheckAllUsers = $false
  )

  if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  try {
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' } | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }

    $testDescription = '
  Microsoft recommends creating at least one Conditional Access policy targeting all cloud apps and ideally all users.

  See [Plan a Conditional Access deployment - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access#apply-conditional-access-policies-to-every-app)'
    if ($SkipCheckAllUsers.IsPresent) {
      $testResult = "These Conditional Access policies target all cloud apps:`n`n"
    } else {
      $testResult = "These Conditional Access policies target all cloud apps and all users:`n`n"
    }

    $result = $false
    foreach ($policy in $policies) {
      if ( ( $SkipCheckAllUsers.IsPresent -or $policy.conditions.users.includeUsers -eq 'All' ) `
          -and $policy.conditions.applications.includeApplications -eq 'All' `
      ) {
        $result = $true
        $currentResult = $true
        $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
      } else {
        $currentResult = $false
      }
      Write-Verbose "$($policy.displayName) - $currentResult"
    }

    if ($result -eq $false) {
      if ($SkipCheckAllUsers.IsPresent) {
        $testResult = 'There was no Conditional Access policy targeting all cloud apps.'
      } else {
        $testResult = 'There was no Conditional Access policy targeting all cloud apps and all users.'
      }
    }

    Add-MtTestResultDetail -Description $testDescription -Result $testResult
    return $result
  } catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
  }

}
