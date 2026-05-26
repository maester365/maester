function Test-MtCisFormsPhishingProtectionEnabledCompliance {
    <#
    .SYNOPSIS
    Checks if the internal phishing protection for Microsoft Forms is enabled.

    .DESCRIPTION
    The internal phishing protection for Microsoft Forms should be enabled.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisFormsPhishingProtectionEnabledCompliance
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

    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "OrgSettings-Forms.Read.All" -notin $scopes
    if ($permissionMissing) {
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/forms/settings" -DisableCache

        Write-Verbose 'Executing checks'
        $CheckIsInOrgFormsPhishingScanEnabled = $settings | Where-Object { $_.isInOrgFormsPhishingScanEnabled -eq $true }

        $testResult = (($CheckIsInOrgFormsPhishingScanEnabled | Measure-Object).Count -ge 1)
        if ($CheckIsInOrgFormsPhishingScanEnabled) {
            $CheckIsInOrgFormsPhishingScanEnabledResult = '✅ Pass'
        }
        else {
            $CheckIsInOrgFormsPhishingScanEnabledResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
