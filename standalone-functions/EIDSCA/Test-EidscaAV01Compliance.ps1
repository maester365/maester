function Test-EidscaAV01Compliance {
    <#
    .SYNOPSIS
    Authentication Method - Voice call - State

    .DESCRIPTION
    Validates EIDSCA control AV01.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAV01Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')'
        $actualValue = $response.state
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'disabled'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AV01: Compliant"
    } else {
        Write-Verbose "EIDSCA AV01: Non-Compliant - Expected: disabled, Actual: $actualValue"
    }

    return $testResult
}
