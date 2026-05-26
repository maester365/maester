function Test-MtCisHostedConnectionFilterPolicyCompliance {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have allow listed IPs
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisHostedConnectionFilterPolicyCompliance
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
        Write-Verbose 'Getting the Hosted Connection Filter policy...'
        $connectionFilterIPAllowList = Get-HostedConnectionFilterPolicy | Where-Object {$_.isDefault -eq $true} | Select-Object IPAllowList

        Write-Verbose 'Check if the Connection Filter IP allow list is empty'
        $testResult = -not $connectionFilterIPAllowList.IPAllowList -or $connectionFilterIPAllowList.IPAllowList.Count -eq 0
        return $testResult
    } catch {
        return $null
    }

}
