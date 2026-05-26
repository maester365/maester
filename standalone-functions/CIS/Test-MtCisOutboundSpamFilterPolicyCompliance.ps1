function Test-MtCisOutboundSpamFilterPolicyCompliance {
    <#
    .SYNOPSIS
    Checks if Exchange Online Spam Policies are set to notify administrators

    .DESCRIPTION
    Ensure Exchange Online Spam Policies are set to notify administrators
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisOutboundSpamFilterPolicyCompliance
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

    try {
        Write-Verbose 'Getting Outbound Spam Filter Policy...'
        $policies = Get-HostedOutboundSpamFilterPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.IsDefault -eq $true }

        $OutboundSpamFilterPolicyCheckList = @()

        #BccSuspiciousOutboundMail should be True
        $OutboundSpamFilterPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'BccSuspiciousOutboundMail'
            'Value'     = 'True'
        }

        #NotifyOutboundSpam should be True
        $OutboundSpamFilterPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'NotifyOutboundSpam'
            'Value'     = 'True'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $OutboundSpamFilterPolicyCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0
        return $testResult
    } catch {
        return $null
    }

}
