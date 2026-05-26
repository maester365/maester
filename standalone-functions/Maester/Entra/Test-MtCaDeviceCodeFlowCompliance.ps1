function Test-MtCaDeviceCodeFlowCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaDeviceCodeFlowCompliance
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
        $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq 'enabled' -and $_.conditions.authenticationFlows.transferMethods -match 'deviceCodeFlow' }
        $policiesResult = New-Object System.Collections.ArrayList
        $result = $false

        foreach ($policy in $policies) {
            if ($policy.conditions.users.includeUsers -eq 'All' -and
                $policy.conditions.clientAppTypes -eq 'all' -and (
                    ($policy.grantControls.builtInControls -contains 'block' -and (-not $policy.conditions.locations -or $policy.conditions.locations.includeLocations -eq 'All')) -or
                    ($policy.grantControls.builtInControls -contains 'compliantDevice' -or $policy.grantControls.builtInControls -contains 'domainJoinedDevice' )
                )
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
        } elseif ( $policies ) {
            $policiesResult = $policies
        } else {
            $testResult = 'No conditional access policy found that targets the Device Code authentication flow.'
        }

        return $result
    } catch {
        return $null
    }

}
