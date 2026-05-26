function Test-EidscaPR05Compliance {
    <#
    .SYNOPSIS
    Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds

    .DESCRIPTION
    Validates EIDSCA control PR05.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaPR05Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/settings'
        $actualValue = $response.values
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = [int]$actualValue -ge 60

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA PR05: Compliant"
    } else {
        Write-Verbose "EIDSCA PR05: Non-Compliant - Expected: 60, Actual: $actualValue"
    }

    return $testResult
}
