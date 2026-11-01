function Test-MtCisTeamsReportSecurityConcerns {
    <#
    .SYNOPSIS
    Ensure users can report security concerns in Teams

    .DESCRIPTION
    Checks that users can report security concerns in Teams, and that reported Teams items and email messages
    go only to the organization's reporting mailbox and not to Microsoft.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.6.1, E5 L1)

    .EXAMPLE
    Test-MtCisTeamsReportSecurityConcerns

    Returns true if users can report security concerns in Teams and reports go only to the reporting mailbox

    .LINK
    https://maester.dev/docs/commands/Test-MtCisTeamsReportSecurityConcerns
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.6.1',
        Title = 'Ensure users can report security concerns in Teams',
        Product = 'teams',
        RelatedProduct = 'defender',
        Feature = 'messaging',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.6.1', 'nist-800-53-r5:IR-6'),
        Service = ('Teams', 'ExchangeOnline'),
        License = ('ATP_ENTERPRISE', 'DEFENDER_XDR'),
        Author = 'HenrikPiecha',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Allow')]
    param()

    Write-Verbose 'Test-MtCisTeamsReportSecurityConcerns: Checking if users can report security concerns in Teams to internal destination'

    $messagingPolicy = Get-CsTeamsMessagingPolicy -Identity Global
    $reportPolicy = @(Get-MtExo -Request ReportSubmissionPolicy) | Select-Object -First 1
    $reportRules = @(Get-MtExo -Request ReportSubmissionRule) | Where-Object { $_ }

    $hasAddress = { param([object[]] $Values) @($Values | Where-Object { "$_" }).Count -gt 0 }
    $ruleAddresses = @($reportRules | Where-Object { $_.State -ne 'Disabled' } | ForEach-Object { $_.SentTo } | Where-Object { "$_" })

    $checks = @(
        [pscustomobject]@{ Setting = 'AllowSecurityEndUserReporting (Teams Global messaging policy)'; Value = $messagingPolicy.AllowSecurityEndUserReporting; Expected = 'True'; Pass = $messagingPolicy.AllowSecurityEndUserReporting -eq $true }
        [pscustomobject]@{ Setting = 'ReportChatMessageEnabled'; Value = $reportPolicy.ReportChatMessageEnabled; Expected = 'False'; Pass = $reportPolicy.ReportChatMessageEnabled -eq $false }
        [pscustomobject]@{ Setting = 'ReportChatMessageToCustomizedAddressEnabled'; Value = $reportPolicy.ReportChatMessageToCustomizedAddressEnabled; Expected = 'True'; Pass = $reportPolicy.ReportChatMessageToCustomizedAddressEnabled -eq $true }
        [pscustomobject]@{ Setting = 'EnableReportToMicrosoft'; Value = $reportPolicy.EnableReportToMicrosoft; Expected = 'False'; Pass = $reportPolicy.EnableReportToMicrosoft -eq $false }
        [pscustomobject]@{ Setting = 'ReportJunkToCustomizedAddress'; Value = $reportPolicy.ReportJunkToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportJunkToCustomizedAddress -eq $true }
        [pscustomobject]@{ Setting = 'ReportNotJunkToCustomizedAddress'; Value = $reportPolicy.ReportNotJunkToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportNotJunkToCustomizedAddress -eq $true }
        [pscustomobject]@{ Setting = 'ReportPhishToCustomizedAddress'; Value = $reportPolicy.ReportPhishToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportPhishToCustomizedAddress -eq $true }
        [pscustomobject]@{ Setting = 'ReportJunkAddresses'; Value = @($reportPolicy.ReportJunkAddresses) -join ', '; Expected = 'Reporting mailbox'; Pass = & $hasAddress $reportPolicy.ReportJunkAddresses }
        [pscustomobject]@{ Setting = 'ReportNotJunkAddresses'; Value = @($reportPolicy.ReportNotJunkAddresses) -join ', '; Expected = 'Reporting mailbox'; Pass = & $hasAddress $reportPolicy.ReportNotJunkAddresses }
        [pscustomobject]@{ Setting = 'ReportPhishAddresses'; Value = @($reportPolicy.ReportPhishAddresses) -join ', '; Expected = 'Reporting mailbox'; Pass = & $hasAddress $reportPolicy.ReportPhishAddresses }
        [pscustomobject]@{ Setting = 'Report submission rule (SentTo)'; Value = $ruleAddresses -join ', '; Expected = 'Enabled rule with the reporting mailbox'; Pass = $ruleAddresses.Count -gt 0 }
    )
    $return = $null -ne $messagingPolicy -and $null -ne $reportPolicy -and @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $result = "| Setting | Value | Expected | Status |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($check in $checks) {
        $displayValue = if ($null -eq $check.Value -or "$($check.Value)" -eq '') { 'Not set' } else { $check.Value }
        $result += "| $($check.Setting) | $displayValue | $($check.Expected) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($return) {
        $testResultMarkdown = "Well done. Users can report security concerns in Teams, and reports go only to your reporting mailbox.`n`n%TestResult%"
    } elseif ($null -eq $reportPolicy) {
        $testResultMarkdown = "No report submission policy was returned, so the reporting destination could not be confirmed. Configure the user reported settings in the Microsoft Defender portal.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Users can't report security concerns in Teams, or reports are not sent only to your reporting mailbox.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}
