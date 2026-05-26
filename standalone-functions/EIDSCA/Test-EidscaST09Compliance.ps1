function Test-EidscaST09Compliance {
    <#
    .SYNOPSIS
    Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content

    .DESCRIPTION
    Validates EIDSCA control ST09.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaST09Compliance
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
    $testResult = $actualValue -eq 'True'

    # Phase 4: Return Result
    if ($testResult) {
        Write-Verbose "EIDSCA ST09: Compliant"
    } else {
        Write-Verbose "EIDSCA ST09: Non-Compliant - Expected: True, Actual: $actualValue"
    }

    return $testResult
}
