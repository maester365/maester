function Test-MtCisEnsureUserConsentToAppsDisallowed {
    <#
    .SYNOPSIS
        Checks if user consent to applications is disallowed.

    .DESCRIPTION
        Users should not be allowed to consent to applications.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.5.1, L2)

    .EXAMPLE
        Test-MtCisEnsureUserConsentToAppsDisallowed

        Returns true if users are not allowed to consent to applications.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisEnsureUserConsentToAppsDisallowed
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.5.1',
        Title = 'Ensure user consent to apps accessing company data on their behalf is not allowed',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Entra ID',
        Tag = ('CIS E3', 'CIS E3 Level 2', 'CIS E5', 'CIS E5 Level 2', 'CIS M365 v7.0.0', 'L2', 'Security'),
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
    $testResult = $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-low" -and $settings.permissionGrantPoliciesAssigned -notcontains "ManagePermissionGrantsForSelf.microsoft-user-default-legacy"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($testResult) {
        $checkResult = '✅ Pass'
    }
    else {
        $checkResult = '❌ Fail'
    }

    $resultMd += "| User consent for applications | $checkResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
