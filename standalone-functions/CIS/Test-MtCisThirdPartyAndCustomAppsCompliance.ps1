function Test-MtCisThirdPartyAndCustomAppsCompliance {
    <#
    .SYNOPSIS
    Ensure all or a majority of third-party and custom apps are blocked

    .DESCRIPTION
    Ensure all or a majority of third-party and custom apps are blocked
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisThirdPartyAndCustomAppsCompliance
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
        $null = Get-CsTenant -ErrorAction Stop
    } catch {
        Write-Verbose "Not connected to Microsoft Teams: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    Write-Verbose 'Test-MtCisThirdPartyAndCustomApps: Checking if all or a majority of third-party and custom apps are blocked'

    try {
        $return = $true
        $appPermPolicy = Get-CsTeamsAppPermissionPolicy -Identity Global

        $passResult = '✅ Pass'
        $failResult = '❌ Fail'

        $result = "| Policy | Value | Status |`n"
        $result += "| --- | --- | --- |`n"

        if (($appPermPolicy.DefaultCatalogAppsType -eq 'BlockedAppList') -and (-not $appPermPolicy.DefaultCatalogApps)) {
            # Microsoft apps
            $result += "| Microsoft apps | Allow all apps | $passResult |`n"
        } elseif (($appPermPolicy.DefaultCatalogAppsType -eq 'AllowedAppList') -and ($appPermPolicy.DefaultCatalogApps)) {
            $result += "| Microsoft apps | Allow specific apps and block all others | $passResult |`n"
            $return = $false
        } elseif (($appPermPolicy.DefaultCatalogAppsType -eq 'BlockedAppList') -and ($appPermPolicy.DefaultCatalogApps)) {
            $result += "| Microsoft apps | Block specific apps and allow all others | $failResult |`n"
        } else {
            $result += "| Microsoft apps | Block all apps | $failResult |`n"
            $return = $false
        }

        if (($appPermPolicy.GlobalCatalogAppsType -eq 'BlockedAppList') -and (-not $appPermPolicy.GlobalCatalogApps)) {
            # Third-party apps
            $result += "| Third-party apps | Allow all apps | $failResult |`n"
            $return = $false
        } elseif (($appPermPolicy.GlobalCatalogAppsType -eq 'AllowedAppList') -and ($appPermPolicy.GlobalCatalogApps)) {
            $result += "| Third-party apps | Allow specific apps and block all others | $passResult |`n"
        } elseif (($appPermPolicy.GlobalCatalogAppsType -eq 'BlockedAppList') -and ($appPermPolicy.GlobalCatalogApps)) {
            $result += "| Third-party apps | Block specific apps and allow all others | $failResult |`n"
            $return = $false
        } else {
            $result += "| Third-party apps | Block all apps | $passResult |`n"
        }

        if (($appPermPolicy.PrivateCatalogAppsType -eq 'BlockedAppList') -and (-not $appPermPolicy.PrivateCatalogApps)) {
            # Custom apps
            $result += "| Custom apps | Allow all apps | $failResult |`n"
            $return = $false
        } elseif (($appPermPolicy.PrivateCatalogAppsType -eq 'AllowedAppList') -and ($appPermPolicy.PrivateCatalogApps)) {
            $result += "| Custom apps | Allow specific apps and block all others | $passResult |`n"
        } elseif (($appPermPolicy.PrivateCatalogAppsType -eq 'BlockedAppList') -and ($appPermPolicy.PrivateCatalogApps)) {
            $result += "| Custom apps | Block specific apps and allow all others | $failResult |`n"
            $return = $false
        } else {
            $result += "| Custom apps | Block all apps | $passResult |`n"
        }

        if ($return) {
        } else {
        }

        return $return
    } catch {
        return $null
    }

}
