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
        $settings = (Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy").defaultUserRolePermissions

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