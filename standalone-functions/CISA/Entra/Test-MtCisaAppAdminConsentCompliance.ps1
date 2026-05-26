function Test-MtCisaAppAdminConsentCompliance {
    <#
    .SYNOPSIS
    Checks if admin consent workflow is configured with reviewers

    .DESCRIPTION
    An admin consent workflow SHALL be configured for applications.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAppAdminConsentCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
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
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy'.0

    $reviewers = $result | Where-Object {`
        $_.isEnabled -and `
        $_.notifyReviewers -and `
        $_.reviewers.Count -ge 1 } | Select-Object -ExpandProperty reviewers

    $testResult = ($reviewers|Measure-Object).Count -ge 1
    return $testResult

}
