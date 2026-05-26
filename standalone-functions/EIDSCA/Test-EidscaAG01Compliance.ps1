function Test-EidscaAG01Compliance {
    <#
    .SYNOPSIS
    Authentication Method - General Settings - Manage migration

    .DESCRIPTION
    Validates EIDSCA control AG01.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAG01Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy'
        $actualValue = $response.policyMigrationState
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -in @('migrationComplete', '')

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AG01: Compliant"
    } else {
        Write-Verbose "EIDSCA AG01: Non-Compliant - Expected: @('migrationComplete', ''), Actual: $actualValue"
    }

    return $testResult
}
