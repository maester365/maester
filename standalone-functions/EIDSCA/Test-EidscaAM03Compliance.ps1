function Test-EidscaAM03Compliance {
    <#
    .SYNOPSIS
    Authentication Method - Microsoft Authenticator - Require number matching for push notifications

    .DESCRIPTION
    Validates EIDSCA control AM03.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAM03Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')'
        $actualValue = $response.featureSettings.numberMatchingRequiredState.state
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'enabled'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AM03: Compliant"
    } else {
        Write-Verbose "EIDSCA AM03: Non-Compliant - Expected: enabled, Actual: $actualValue"
    }

    return $testResult
}
