function Test-EidscaAM02Compliance {
    <#
    .SYNOPSIS
    Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP

    .DESCRIPTION
    Validates EIDSCA control AM02.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAM02Compliance
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
        $actualValue = $response.isSoftwareOathEnabled
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'false'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AM02: Compliant"
    } else {
        Write-Verbose "EIDSCA AM02: Non-Compliant - Expected: false, Actual: $actualValue"
    }

    return $testResult
}
