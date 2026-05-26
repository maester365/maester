function Test-EidscaCR04Compliance {
    <#
    .SYNOPSIS
    Consent Framework - Admin Consent Request - Consent request duration (days)

    .DESCRIPTION
    Validates EIDSCA control CR04.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaCR04Compliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection
    try {
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy'
        $actualValue = $response.requestDurationInDays
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = [int]$actualValue -le 30

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA CR04: Compliant"
    } else {
        Write-Verbose "EIDSCA CR04: Non-Compliant - Expected: 30, Actual: $actualValue"
    }

    return $testResult
}
