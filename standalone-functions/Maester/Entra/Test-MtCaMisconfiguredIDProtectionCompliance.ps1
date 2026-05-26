function Test-MtCaMisconfiguredIDProtectionCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaMisconfiguredIDProtectionCompliance
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
        $policiesResult = New-Object System.Collections.ArrayList

        $result = $false
        $hasRiskCAPolicy = $false # flag to check if there is any policy with risk controls, we skip the test if there is none

        foreach ($policy in $policies) {
            if ($policy.conditions.userRiskLevels -or $policy.conditions.signInRiskLevels) {
                $hasRiskCAPolicy = $true
            }
            if ($policy.conditions.userRiskLevels -and $policy.conditions.signInRiskLevels) {
                $result = $true
                $CurrentResult = $true
                $policiesResult.Add($policy) | Out-Null
            } else {
                $CurrentResult = $false
            }
            Write-Verbose "$($policy.displayName) - $CurrentResult"
        }

        if ( -not $hasRiskCAPolicy ) {
            return $null
        }

        if ( $result ) {
        } else {
            $testResult = 'Well done! No conditional access policies detected where sign-in risk and user risk are combined.'
        }

        return $result
    } catch {
        return $false
    }

}
