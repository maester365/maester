function Test-EidscaAT02Compliance {
    <#
    .SYNOPSIS
    Authentication Method - Temporary Access Pass - One-time

    .DESCRIPTION
    Validates EIDSCA control AT02.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAT02Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')'
        $actualValue = $response.isUsableOnce
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'true'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AT02: Compliant"
    } else {
        Write-Verbose "EIDSCA AT02: Non-Compliant - Expected: true, Actual: $actualValue"
    }

    return $testResult
}
