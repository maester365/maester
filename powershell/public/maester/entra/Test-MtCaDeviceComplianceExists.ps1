<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring device compliance.

 .Description
  Device compliance conditional access policy can be used to require devices to be compliant with the tenant's device compliance policy.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device

 .Example
  Test-MtCaDeviceComplianceExists

.LINK
    https://maester.dev/docs/commands/Test-MtCaDeviceComplianceExists
#>
function Test-MtCaDeviceComplianceExists {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  if ( ( Get-MtLicenseInformation EntraID ) -eq 'Free' ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

  try {
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

    $result = $false

    $testDescription = '
It is recommended to have at least one conditional access policy that enforces the use of a compliant device.

See [Require a compliant device, Microsoft Entra hybrid joined device, or MFA - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device)'
    $testResult = "These conditional access policies enforce the use of a compliant device :`n`n"

    foreach ($policy in $policies) {
      if ($policy.grantControls.builtInControls -contains 'compliantDevice') {
        Write-Verbose -Message "Found a conditional access policy requiring device compliance: $($policy.displayName)"
        $result = $true
        $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
      }
    }

    if ($result -eq $false) {
      $testResult = 'There was no conditional access policy requiring device compliance.'
    }
    Add-MtTestResultDetail -Description $testDescription -Result $testResult

    return $result
  } catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
  }
}
