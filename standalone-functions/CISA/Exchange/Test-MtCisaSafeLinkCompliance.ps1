function Test-MtCisaSafeLinkCompliance {
    <#
    .SYNOPSIS
    Checks state of URL block list

    .DESCRIPTION
    URL comparison with a block-list SHOULD be enabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSafeLinkCompliance
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
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    try {
        $sccSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.ComputerName -match 'compliance' -and $_.State -eq 'Opened' }
        if ($null -eq $sccSession) {
            Write-Verbose "Not connected to Security & Compliance Center"
            return $null
        }
    } catch {
        Write-Verbose "Security & Compliance connection check failed: $_"
        return $null
    }

    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'MDE_ATP|THREAT_INTELLIGENCE|ATP_ENTERPRISE' }
        if ($null -eq $sku) {
            Write-Verbose "Microsoft Defender for Office 365 P1 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $policies = Get-SafeLinksPolicy

    $resultPolicies = $policies | Where-Object { `
            $_.EnableSafeLinksForEmail
    }

    $standard = $policies | Where-Object { `
            $_.RecommendedPolicyType -eq 'Standard'
    }

    $strict = $policies | Where-Object { `
            $_.RecommendedPolicyType -eq 'Strict'
    }

    $testResult = $standard -and $strict -and (($resultPolicies | Measure-Object).Count -ge 1)

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'
    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if ($standard) {
        $result += "| Standard | $passResult |`n"
    } else {
        $result += "| Standard | $failResult |`n"
    }
    if ($strict) {
        $result += "| Strict | $passResult |`n`n"
    } else {
        $result += "| Strict | $failResult |`n`n"
    }

    $result += "| Policy Name | Policy Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $policies | Sort-Object -Property Identity) {
        if ($item.Guid -in $resultPolicies.Guid) {
            $result += "| $($item.Identity) | $passResult |`n"
        } else {
            $result += "| $($item.Identity) | $failResult |`n"
        }
    }


    return $testResult

}
