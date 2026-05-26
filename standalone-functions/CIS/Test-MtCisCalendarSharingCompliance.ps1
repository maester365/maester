function Test-MtCisCalendarSharingCompliance {
    <#
    .SYNOPSIS
    Checks state of sharing policies

    .DESCRIPTION
    Calendar details SHALL NOT be shared with all domains.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisCalendarSharingCompliance
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
        Write-Verbose 'Get Calendar sharing policy'
        $policies = Get-SharingPolicy

        Write-Verbose 'Get Calendars where sharing policy is enabled and allows anonymous sharing'
        $resultPolicies = $policies | Where-Object {
            $_.Enabled -and ($_.Domains -like "`*:*CalendarSharing*" -or $_.Domains -like 'Anonymous:*CalendarSharing*')
        }

        $testResult = ($resultPolicies | Measure-Object).Count -eq 0
        $result = "| Policy Name | Test Result |`n"
        $result += "| --- | --- |`n"
        return $testResult
    } catch {
        return $null
    }

}
