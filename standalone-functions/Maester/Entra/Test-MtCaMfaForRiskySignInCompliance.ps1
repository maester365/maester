function Test-MtCaMfaForRiskySignInCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaMfaForRiskySignInCompliance
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
    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'AAD_PREMIUM_P2' }
        if ($null -eq $sku) {
            Write-Verbose "Entra ID P2 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }
        # Remove policies that require password change, as they are related to user risk and not MFA on signin
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -notcontains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                (
                    $policy.grantControls.builtInControls -contains 'mfa' -or
                    $policy.grantControls.authenticationStrength.requirementsSatisfied -contains 'mfa'
                ) -and
                $policy.conditions.users.includeUsers -eq "All" -and
                $policy.conditions.applications.includeApplications -eq "All" -and
                "high" -in $policy.conditions.signInRiskLevels -and
                "medium" -in $policy.conditions.signInRiskLevels
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
            $testResult = "No conditional access policy requires multi-factor authentication for risky sign-ins."
        }

        return $result
    } catch {
        return $null
    }

}
