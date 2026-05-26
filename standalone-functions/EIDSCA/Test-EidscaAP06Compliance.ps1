function Test-EidscaAP06Compliance {
    <#
    .SYNOPSIS
    Default Authorization Settings - User can join the tenant by email validation

    .DESCRIPTION
    Validates EIDSCA control AP06.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAP06Compliance
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
        $actualValue = $response.allowEmailVerifiedUsersToJoinOrganization
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq 'false'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AP06: Compliant"
    } else {
        Write-Verbose "EIDSCA AP06: Non-Compliant - Expected: false, Actual: $actualValue"
    }

    return $testResult
}
