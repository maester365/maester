function Test-MtExoSetSclCompliance {
    <#
    .SYNOPSIS
    Checks if Spam confidence level (SCL) is configured in mail transport rules with specific domains

    .DESCRIPTION
    This command checks if Spam confidence level (SCL) is properly configured in mail transport rules.
    Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can
    enable an attacker to launch attacks against your users from a safe haven domain.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtExoSetSclCompliance
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

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {

        Write-Verbose "Getting Transport Rules..."
        $exchangeTransportRule = Get-TransportRule
        Write-Verbose "Found $($exchangeTransportRule.Count) Exchange Transport rules"

        $ruleWithSCL = $exchangeTransportRule | Where-Object { $_.SetScl -match "-1" }
        $result = ($ruleWithSCL).Count -gt 0

        if ($result -eq $false) {
        } else {
        }

    } catch {
        return $null
    }

    return !$result

}
