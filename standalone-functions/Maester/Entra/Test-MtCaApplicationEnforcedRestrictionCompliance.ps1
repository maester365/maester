function Test-MtCaApplicationEnforcedRestrictionCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaApplicationEnforcedRestrictionCompliance
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
Microsoft recommends blocking or limiting access to SharePoint, OneDrive, and Exchange content from unmanaged devices.

See [Use application enforced restrictions for unmanaged devices - Microsoft Learn](https://aka.ms/CATemplatesAppRestrictions)'
        $testResult = "These conditional access policies enforce restrictions for unmanaged devices:`n`n"

        $result = $false
        foreach ($policy in $policies) {
            if ( $policy.conditions.users.includeUsers -eq 'All' `
                    -and $policy.conditions.clientAppTypes -eq 'All' `
                    -and $policy.sessionControls.applicationEnforcedRestrictions.isEnabled -eq $true `
                    -and 'Office365' -in $policy.conditions.applications.includeApplications `
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
            $testResult = 'There was no conditional access policy enforcing restrictions for unmanaged devices.'
        }

        return $result
    } catch {
        return $null
    }

}
