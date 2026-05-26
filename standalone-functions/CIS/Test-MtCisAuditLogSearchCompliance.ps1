function Test-MtCisAuditLogSearchCompliance {
    <#
    .SYNOPSIS
    Checks if audit log search is enabled

    .DESCRIPTION
    Microsoft 365 audit log search should be enabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisAuditLogSearchCompliance
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
        Write-Verbose 'Get audit log search status'
        $auditLogSearch = Get-AdminAuditLogConfig

        if ($auditLogSearch | Where-Object { $_.UnifiedAuditLogIngestionEnabled -ne 'True' }) {
            $testResult = $false
        } else {
            $testResult = $true
        }

        foreach ($item in $auditLogSearch) {
            if ($item.UnifiedAuditLogIngestionEnabled) {
            } else {
            }
        }


        return $testResult
    } catch {
        return $null
    }

}
