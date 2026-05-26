function Test-MtCaSecureSecurityInfoRegistrationCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaSecureSecurityInfoRegistrationCompliance
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
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }
        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                $policy.conditions.users.includeUsers -eq "All" -and
                $policy.conditions.clientAppTypes -eq "all" -and
                $policy.conditions.applications.includeUserActions -eq "urn:user:registersecurityinfo" -and
                $policy.conditions.locations.includeLocations -eq "All" -and
                $null -ne $policy.conditions.locations.excludeLocations
            ) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( $result ) {
        } else {
            $testResult = "No conditional access policy securing security info registration."
        }

        return $result
    } catch {
        return $false
    }

}
