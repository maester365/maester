function Test-MtCaDeviceComplianceExistsCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaDeviceComplianceExistsCompliance
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

  try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq 'enabled' }

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

    return $result
  } catch {
    return $null
  }

}
