function Test-MtCaRequirePasswordChangeForHighUserRiskCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaRequirePasswordChangeForHighUserRiskCompliance
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
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq 'enabled' }
        # Only check policies that have password change as a grant control
        $policies = $policies | Where-Object { $_.grantControls.builtInControls -contains 'passwordChange' }
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        foreach ($policy in $policies) {
            if (
                $policy.grantControls.builtInControls -contains 'passwordChange' -and
                $policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.applications.includeApplications -eq 'All' -and
                'high' -in $policy.conditions.userRiskLevels
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
            $testResult = 'No conditional access policy requires a password change for risky users.'
        }

        return $result
    } catch {
        return $false
    }

}
