function Test-MtCisAdminConsentWorkflowEnabledCompliance {
    <#
    .SYNOPSIS
    Checks if the admin consent workflow is enabled

    .DESCRIPTION
    The admin consent workflow should be enabled.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisAdminConsentWorkflowEnabledCompliance
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

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy' -DisableCache

        Write-Verbose 'Executing checks'
        $checkAdminConsentWorkflowEnabled = $settings | Where-Object { $_.isEnabled -eq $true }

        $testResult = (($checkAdminConsentWorkflowEnabled | Measure-Object).Count -ge 1)
        if ($checkAdminConsentWorkflowEnabled) {
            $checkAdminConsentWorkflowEnabledResult = '✅ Pass'
        }
        else {
            $checkAdminConsentWorkflowEnabledResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
