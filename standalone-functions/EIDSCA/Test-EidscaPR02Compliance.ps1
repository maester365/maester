function Test-EidscaPR02Compliance {
    <#
    .SYNOPSIS
    Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory

    .DESCRIPTION
    Validates EIDSCA control PR02.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-EidscaPR02Compliance
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
        Write-Verbose "EIDSCA PR02: Compliant"
    } else {
        Write-Verbose "EIDSCA PR02: Non-Compliant - Expected: True, Actual: $actualValue"
    }

    return $testResult
}
