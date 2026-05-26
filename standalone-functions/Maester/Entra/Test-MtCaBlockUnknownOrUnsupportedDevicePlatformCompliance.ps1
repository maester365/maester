function Test-MtCaBlockUnknownOrUnsupportedDevicePlatformCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaBlockUnknownOrUnsupportedDevicePlatformCompliance
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

        $testDescription = '
Microsoft recommends blocking access for unknown or unsupported device platforms.

See [Block access for unknown or unsupported device platform - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-policy-unknown-unsupported-device)'
        $testResult = "These conditional access policies block access for unknown or unsupported device platforms:`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.grantControls.builtInControls -eq 'block' `
                    -and $policy.conditions.platforms.includePlatforms -eq 'All'
            ) {
                $result = $true
                $CurrentResult = $true
                $testResult += "  - [$($policy.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ($result -eq $false) {
            $testResult = 'There was no conditional access policy blocking access for unknown or unsupported device platforms.'
        }

        return $result
    } catch {
        return $null
    }

}
