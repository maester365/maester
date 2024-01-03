<#
 .Synopsis
  Checks if the tenant has at least one fallback policy targetting All Apps and All Users.

 .Description
  Microsoft recommends creating at least one conditional access policy targetting all cloud apps
  and ideally should be enabled for all users.

  Learn more:
  https://learn.microsoft.com/en-us/entra/identity/conditional-access/plan-conditional-access#apply-conditional-access-policies-to-every-app

 .Example
  Test-MtCaAllAppsExists

  Test-MtCaAllAppsExists -SkipCheckAllUsers
#>

Function Test-MtCaAllAppsExists {
  [CmdletBinding()]
  [OutputType([bool])]
  param (

    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [switch] $SkipCheckAllUsers = $false
  )

  $policies = Get-MtConditionalAccessPolicies

  Set-StrictMode -Off

  $result = $false
  foreach ($policy in $policies) {
    if ($policy.value.conditions.applications.includeApplications -eq 'all' `
        -and $policy.value.state -eq 'enabled') {

      $result = $SkipCheckAllUsers.IsPresent `
        -or $policy.value.conditions.users.includeusers -eq 'all'
    }
  }

  return $result
}