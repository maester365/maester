<#
.SYNOPSIS
    Checks if user consent to applications is disallowed.

.DESCRIPTION
    Users should not be allowed to consent to applications.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisEnsureUserConsentToAppsDisallowed

    Returns true if users are not allowed to consent to applications.

.LINK
    https://maester.dev/docs/commands/Test-MtCisEnsureUserConsentToAppsDisallowed
#>
function Test-MtCisEnsureUserConsentToAppsDisallowed {
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
        $testResult = $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-low" -and $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-legacy"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($testResult) {
            $checkResult = '✅ Pass'
        } else {
            $checkResult = '❌ Fail'
        }

        $resultMd += "| User consent for applications | $checkResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}