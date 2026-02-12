<#
.SYNOPSIS
    Checks if users are not allowed to register applications.

.DESCRIPTION
    Users should not be allowed to register applications in the tenant.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisThirdPartyApplicationsDisallowed

    Returns true if users are not allowed to register applications in the tenant.

.LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyApplicationsDisallowed
#>
function Test-MtCisThirdPartyApplicationsDisallowed {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = (Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -DisableCache).defaultUserRolePermissions

        Write-Verbose 'Executing checks'
        $checkAllowedToCreateApps = $settings | Where-Object { $_.allowedToCreateApps -eq $false }

        $testResult = (($checkAllowedToCreateApps | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($checkAllowedToCreateApps) {
            $checkAllowedToCreateAppsResult = '✅ Pass'
        } else {
            $checkAllowedToCreateAppsResult = '❌ Fail'
        }

        $resultMd += "| Users can register applications | $checkAllowedToCreateAppsResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}