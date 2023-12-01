<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring device compliance.

 .Description
  Device compliance conditional access policy can be used to require devices to be compliant with the tenant's device compliance policy.

  Learn more:
  https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device

 .Example
  Test-MtCaHasDeviceCompliance
#>

Function Test-MtCaHasDeviceCompliance {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    # The policies in the tenant, returned by Get-MtConditionalAccessPolicies
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [object] $Policies
  )

  $policies = Get-MtConditionalAccessPolicies

  $result = & { Set-StrictMode -Off; $policies.value.grantcontrols.builtincontrols -contains 'compliantDevice' }
  return $result

}