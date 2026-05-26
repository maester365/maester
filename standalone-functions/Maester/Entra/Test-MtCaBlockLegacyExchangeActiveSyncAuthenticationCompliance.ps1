function Test-MtCaBlockLegacyExchangeActiveSyncAuthenticationCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaBlockLegacyExchangeActiveSyncAuthenticationCompliance
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
Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
conditional access policy that blocks legacy authentication.

See [Block legacy authentication - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy)'
        $testResult = "These conditional access policies block legacy authentication for Exchange Active Sync:`n`n"


        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.grantControls.builtInControls -contains 'block' -and
                'exchangeActiveSync' -in $policy.conditions.clientAppTypes -and (
                    $policy.conditions.applications.includeApplications -eq '00000002-0000-0ff1-ce00-000000000000' -or
                    $policy.conditions.applications.includeApplications -eq 'All'
                ) -and $policy.conditions.users.includeUsers -eq 'All'
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
            $testResult = 'There was no conditional access policy blocking legacy authentication for Exchange Active Sync.'
        }

        return $result
    } catch {
        return $null
    }

}
