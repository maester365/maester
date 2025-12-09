<#
.SYNOPSIS
    Ensure all or a majority of third-party and custom apps are blocked

.DESCRIPTION
    Ensure all or a majority of third-party and custom apps are blocked
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisThirdPartyAndCustomApps

    Returns true if all or a majority of third-party and custom apps are blocked

.LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyAndCustomApps
#>
function Test-MtCisThirdPartyAndCustomApps {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple types of apps.')]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

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
            $testResultMarkdown = "Well done. All or a majority of third-party and custom apps are blocked.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "All or a majority of third-party or custom apps are allowed.`n`n%TestResult%"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
