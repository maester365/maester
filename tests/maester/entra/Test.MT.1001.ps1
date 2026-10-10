function Test-MtCaDeviceComplianceExists {
    <#
    .Synopsis
    Checks if the tenant has at least one Conditional Access policy requiring device compliance.

    .Description
    Device compliance Conditional Access policy can be used to require devices to be compliant with the tenant's device compliance policy.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device

    .Example
    Test-MtCaDeviceComplianceExists

    .LINK
    https://maester.dev/docs/commands/Test-MtCaDeviceComplianceExists
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
  [MaesterTest(
      Id = 'MT.1001',
      Title = 'At least one Conditional Access policy is configured with device compliance.',
      Severity = 'Medium',
      Category = 'Maester/Entra',
      Product = 'Entra ID',
      Tag = ('CA', 'Maester'),
      Service = 'Graph',
      License = 'AAD_PREMIUM',
      Author = 'merill',
      Contributor = ('f-bader', 'weyCC81')
  )]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' }

  $result = $false

  $testDescription = '
It is recommended to have at least one Conditional Access policy that enforces the use of a compliant device.

See [Require a compliant device, Microsoft Entra hybrid joined device, or MFA - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device)'
  $testResult = "These Conditional Access policies enforce the use of a compliant device :`n`n"

  foreach ($policy in $policies) {
    if ($policy.grantControls.builtInControls -contains 'compliantDevice') {
      Write-Verbose -Message "Found a Conditional Access policy requiring device compliance: $($policy.displayName)"
      $result = $true
      $testResult += "  - [$(Get-MtSafeMarkdown $policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
    }
  }

  if ($result -eq $false) {
    $testResult = 'There was no Conditional Access policy requiring device compliance.'
  }
  Add-MtTestResultDetail -Description $testDescription -Result $testResult

  return $result
}
