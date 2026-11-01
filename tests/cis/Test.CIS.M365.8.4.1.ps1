function Test-MtCisThirdPartyAndCustomApps {
    <#
    .SYNOPSIS
    Ensure app permission policies are configured

    .DESCRIPTION
    The Teams org-wide app settings should not let users install and use third-party or custom apps by default,
    and should not let users interact with custom apps in preview.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.4.1, L1)

    .EXAMPLE
    Test-MtCisThirdPartyAndCustomApps

    Returns true if the org-wide app settings turn off third-party apps, custom apps and custom apps in preview by default

    .LINK
    https://maester.dev/docs/commands/Test-MtCisThirdPartyAndCustomApps
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.4.1',
        Title = 'Ensure app permission policies are configured',
        Product = 'teams',
        Feature = 'apps',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1195', 'T1671'),
        Control = ('cis-m365:8.4.1', 'nist-800-53-r5:CM-7'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = ('merill', 'MarcoJanse', 'Mynster9361')
    )]
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple types of apps.')]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisThirdPartyAndCustomApps: Checking the Teams org-wide app settings'

    $tenantSettings = @(Get-M365UnifiedTenantSettings)
    $customAppSetting = Get-CsTeamsSettingsCustomApp

    $thirdParty = ($tenantSettings | Where-Object { $_.SettingName -eq 'GlobalApp' } | Select-Object -First 1).SettingValue
    $custom = ($tenantSettings | Where-Object { $_.SettingName -eq 'PrivateApp' } | Select-Object -First 1).SettingValue
    $preview = $customAppSetting.IsSideloadedAppsInteractionEnabled

    $checks = @(
        [pscustomobject]@{ Setting = 'Third-party apps: Let users install and use available apps by default'; Value = $thirdParty; Pass = $thirdParty -eq 'None' }
        [pscustomobject]@{ Setting = 'Custom apps: Let users install and use available apps by default'; Value = $custom; Pass = $custom -eq 'None' }
        [pscustomobject]@{ Setting = 'Custom apps: Let users interact with custom apps in preview'; Value = $preview; Pass = $preview -eq $false }
    )
    $return = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $result = "| Setting | Value | Status |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $displayValue = if ($null -eq $check.Value) { 'Not found' } else { $check.Value }
        $result += "| $($check.Setting) | $displayValue | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($return) {
        $testResultMarkdown = "Well done. Users can't install third-party or custom apps by default or interact with custom apps in preview.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The org-wide app settings let users install third-party or custom apps by default, or interact with custom apps in preview.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}
