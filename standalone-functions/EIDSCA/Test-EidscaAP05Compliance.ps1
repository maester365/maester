function Test-EidscaAP05Compliance {
    <#
    .SYNOPSIS
    Default Authorization Settings - Sign-up for email based subscription

    .DESCRIPTION
    Validates EIDSCA control AP05.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAP05Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authorizationPolicy'
        $actualValue = $response.allowedToSignUpEmailBasedSubscriptions
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'false'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AP05: Compliant"
    } else {
        Write-Verbose "EIDSCA AP05: Non-Compliant - Expected: false, Actual: $actualValue"
    }

    return $testResult
}
