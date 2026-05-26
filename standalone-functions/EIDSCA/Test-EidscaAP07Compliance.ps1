function Test-EidscaAP07Compliance {
    <#
    .SYNOPSIS
    Default Authorization Settings - Guest user access

    .DESCRIPTION
    Validates EIDSCA control AP07.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaAP07Compliance
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
        $actualValue = $response.guestUserRoleId
    } catch {
        Write-Verbose "Data collection failed: $_"
        return $null
    }

    # Phase 3: Compliance Validation
    $testResult = $actualValue -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA AP07: Compliant"
    } else {
        Write-Verbose "EIDSCA AP07: Non-Compliant - Expected: 2af84b1e-32c8-42b7-82bc-daa82404023b, Actual: $actualValue"
    }

    return $testResult
}
