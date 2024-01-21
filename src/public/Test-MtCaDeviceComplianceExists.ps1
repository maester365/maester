<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring device compliance.

 .Description
  Device compliance conditional access policy can be used to require devices to be compliant with the tenant's device compliance policy.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device

 .Example
  Test-MtCaDeviceComplianceExists
#>

Function Test-MtCaDeviceComplianceExists {
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  Set-StrictMode -Off
  $policies = Get-MtConditionalAccessPolicies

  $result = $false
  foreach ($policy in $policies) {
    if ($policy.grantcontrols.builtincontrols -contains 'compliantDevice' `
        -and $policy.state -eq 'enabled' `
    ) {
      $result = $true
    }
  }
  Set-StrictMode -Version Latest

  return $result
}