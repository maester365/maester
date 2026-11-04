function Test-MtCisMailTipsEnabled {
    <#
    .SYNOPSIS
        Checks that all MailTips are enabled and the large audience threshold is set.

    .DESCRIPTION
        Checks the Exchange Online organisation configuration and passes when all MailTips, external recipient tips and group metrics are enabled and a positive large audience threshold is set. CIS leaves the threshold value to the organization and notes 25 as the default.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.5.2, L1)

    .EXAMPLE
        Test-MtCisMailTipsEnabled

        Returns true if MailTips are enabled for end users.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.5.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.5.2',
        Title = 'Ensure MailTips are enabled for end users',
        Product = 'exchange',
        Feature = 'outlook',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:6.5.2', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $orgConfig = Get-MtExo -Request OrganizationConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'MailTipsAllTipsEnabled'; Value = $(if ($null -eq ($orgConfig.MailTipsAllTipsEnabled)) { 'Not found' } else { $orgConfig.MailTipsAllTipsEnabled }); Pass = [bool]($orgConfig.MailTipsAllTipsEnabled -eq $true) }
        [pscustomobject]@{ Setting = 'MailTipsExternalRecipientsTipsEnabled'; Value = $(if ($null -eq ($orgConfig.MailTipsExternalRecipientsTipsEnabled)) { 'Not found' } else { $orgConfig.MailTipsExternalRecipientsTipsEnabled }); Pass = [bool]($orgConfig.MailTipsExternalRecipientsTipsEnabled -eq $true) }
        [pscustomobject]@{ Setting = 'MailTipsGroupMetricsEnabled'; Value = $(if ($null -eq ($orgConfig.MailTipsGroupMetricsEnabled)) { 'Not found' } else { $orgConfig.MailTipsGroupMetricsEnabled }); Pass = [bool]($orgConfig.MailTipsGroupMetricsEnabled -eq $true) }
        [pscustomobject]@{ Setting = 'MailTipsLargeAudienceThreshold'; Value = $(if ($null -eq ($orgConfig.MailTipsLargeAudienceThreshold)) { 'Not found' } else { $orgConfig.MailTipsLargeAudienceThreshold }); Pass = [bool]($orgConfig.MailTipsLargeAudienceThreshold -gt 0) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'MailTips are enabled for end users and a positive large-audience threshold is set.'
    $failText = 'MailTips are not fully enabled for end users.'

    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
