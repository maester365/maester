function Test-MtCisConnectionFilterSafeListCompliance {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have the safe list enabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisConnectionFilterSafeListCompliance
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
        $connectionFilterSafeList = Get-HostedConnectionFilterPolicy | Where-Object {$_.isDefault -eq $true} | Select-Object EnableSafeList

        Write-Verbose 'Check if the Connection Filter safe list is enabled'
        $result = $connectionFilterSafeList.EnableSafeList

        # We need to Invert the $result that we don't need to change the Markdown. False in $result is good and True is bad
        $testResult = -not $result
        return $testResult
    } catch {
        return $null
    }

}
