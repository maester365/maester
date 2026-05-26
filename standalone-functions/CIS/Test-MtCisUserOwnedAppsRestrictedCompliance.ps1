function Test-MtCisUserOwnedAppsRestrictedCompliance {
    <#
    .SYNOPSIS
    Checks if users are restricted to install add-ins from the Office Store and start trials on behalf of the organization.

    .DESCRIPTION
    Users should be restricted to install add-ins from the Office Store and start trials on behalf of the organization.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisUserOwnedAppsRestrictedCompliance
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
    $permissionMissing = "OrgSettings-AppsAndServices.Read.All" -notin $scopes
    if ($permissionMissing) {
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/appsAndServices/settings" -DisableCache

        Write-Verbose 'Executing checks'
        $CheckIsOfficeStoreEnabled = $settings | Where-Object { $_.isOfficeStoreEnabled -eq $false }
        $CheckIsAppAndServicesTrialEnabled = $settings | Where-Object { $_.isAppAndServicesTrialEnabled -eq $false }

        $testResult = (($CheckIsOfficeStoreEnabled | Measure-Object).Count -ge 1) -and (($CheckIsAppAndServicesTrialEnabled | Measure-Object).Count -ge 1)
        if ($CheckIsOfficeStoreEnabled) {
            $CheckIsOfficeStoreEnabledResult = '✅ Pass'
        }
        else {
            $CheckIsOfficeStoreEnabledResult = '❌ Fail'
        }

        if ($CheckIsAppAndServicesTrialEnabled) {
            $CheckIsAppAndServicesTrialEnabledResult = '✅ Pass'
        }
        else {
            $CheckIsAppAndServicesTrialEnabledResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
