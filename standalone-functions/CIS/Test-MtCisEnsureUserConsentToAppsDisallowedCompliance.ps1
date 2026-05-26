function Test-MtCisEnsureUserConsentToAppsDisallowedCompliance {
    <#
    .SYNOPSIS
    Checks if user consent to applications is disallowed.

    .DESCRIPTION
    Users should not be allowed to consent to applications.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisEnsureUserConsentToAppsDisallowedCompliance
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
        $settings = (Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy' -DisableCache).defaultUserRolePermissions

        Write-Verbose 'Executing checks'
        $testResult = $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-low" -and $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-legacy"
        if ($testResult) {
            $checkResult = '✅ Pass'
        }
        else {
            $checkResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
