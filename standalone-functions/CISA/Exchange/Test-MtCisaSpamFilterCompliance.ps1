function Test-MtCisaSpamFilterCompliance {
    <#
    .SYNOPSIS
    Checks state of spam filter

    .DESCRIPTION
    A spam filter SHALL be enabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSpamFilterCompliance
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

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $policies = Get-HostedContentFilterPolicy

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($policies|Measure-Object).Count -ge 1)

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
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

    $result += "| Policy Name | Spam Action | High Confidence Spam Action | Bulk Spam Action | Phish Spam Action |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        $result += "| $($item.Identity) | $($item.SpamAction) | $($item.HighConfidenceSpamAction) | $($item.BulkSpamAction) | $($item.PhishSpamAction) |`n"
    }


    return $testResult

}
