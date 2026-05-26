function Test-EidscaAS04Compliance {
    <#
    .SYNOPSIS
    Authentication Method - SMS - Use for sign-in

    .DESCRIPTION
    Validates EIDSCA control AS04.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAS04Compliance
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
        $response = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')'
        $actualValue = $response.includeTargets.isUsableForSignIn
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'false'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AS04: Compliant"
    } else {
        Write-Verbose "EIDSCA AS04: Non-Compliant - Expected: false, Actual: $actualValue"
    }

    return $testResult
}
