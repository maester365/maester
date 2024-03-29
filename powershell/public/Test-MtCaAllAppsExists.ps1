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

Function Test-MtCaAllAppsExists {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Exists is not a plurality')]
  [CmdletBinding()]
  [OutputType([bool])]
  param (

    [Parameter(Position = 0)]
    [switch] $SkipCheckAllUsers = $false
  )

  $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

  $result = $false
  foreach ($policy in $policies) {
    if ( ( $SkipCheckAllUsers.IsPresent -or $policy.conditions.users.includeUsers -eq "All" ) `
        -and $policy.conditions.applications.includeApplications -eq 'all' `
    ) {
      $result = $true
      $currentresult = $true
    } else {
      $currentresult = $false
    }
    Write-Verbose "$($policy.displayName) - $currentresult"
  }

  return $result
}