function Test-MtCisThirdPartyApplicationsDisallowed {
    <#
    .SYNOPSIS
        Checks if users cannot register applications.

    .DESCRIPTION
        Users should not be allowed to register applications in the tenant.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.2.2, L1)

    .EXAMPLE
        Test-MtCisThirdPartyApplicationsDisallowed

        Returns true if users are not allowed to register applications in the tenant.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisThirdPartyApplicationsDisallowed
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.2.2',
        Title = 'Ensure users cannot register applications',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Entra ID',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'Security'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $settings = (Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -DisableCache).defaultUserRolePermissions

    Write-Verbose 'Executing checks'
    $checkAllowedToCreateApps = $settings | Where-Object { $_.allowedToCreateApps -eq $false }

    $testResult = (($checkAllowedToCreateApps | Measure-Object).Count -ge 1)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($checkAllowedToCreateApps) {
        $checkAllowedToCreateAppsResult = '✅ Pass'
    }
    else {
        $checkAllowedToCreateAppsResult = '❌ Fail'
    }

    $resultMd += "| Users can register applications | $checkAllowedToCreateAppsResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
