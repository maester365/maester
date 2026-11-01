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

    $ruleAddresses = @(
        $reportRules |
            Where-Object { $_.State -eq 'Enabled' } |
            ForEach-Object { $_.SentTo } |
            Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") }
    )
    $destinationValues = [ordered]@{
        ReportJunkAddresses                = @($reportPolicy.ReportJunkAddresses)
        ReportNotJunkAddresses             = @($reportPolicy.ReportNotJunkAddresses)
        ReportPhishAddresses               = @($reportPolicy.ReportPhishAddresses)
        'Report submission rule (SentTo)' = $ruleAddresses
        ReportChatMessageAddresses         = @($reportPolicy.ReportChatMessageAddresses)
    }
    $reportingMailbox = @(
        $destinationValues.Values |
            ForEach-Object { $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") } |
            Select-Object -First 1
    )[0]
    $normalizedMailbox = if ($reportingMailbox) { "$reportingMailbox".Trim().ToLowerInvariant() } else { $null }
    $destinationChecks = foreach ($destination in $destinationValues.GetEnumerator()) {
        $addresses = @(
            $destination.Value |
                Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") } |
                ForEach-Object { "$_".Trim().ToLowerInvariant() } |
                Sort-Object -Unique
        )
        $displayAddresses = @(
            $destination.Value |
                Where-Object { -not [string]::IsNullOrWhiteSpace("$($_)") } |
                ForEach-Object { "$_".Trim() } |
                Sort-Object -Unique
        )
        [pscustomobject]@{
            Setting  = $destination.Key
            Value    = $displayAddresses -join ', '
            Expected = if ($reportingMailbox) { $reportingMailbox } else { 'One reporting mailbox' }
            Pass     = $null -ne $normalizedMailbox -and $addresses.Count -eq 1 -and $addresses[0] -eq $normalizedMailbox
        }
    }
    $teamsAddressCheck = $destinationChecks | Where-Object { $_.Setting -eq 'ReportChatMessageAddresses' }

    $checks = @(
        [pscustomobject]@{ Setting = 'AllowSecurityEndUserReporting (Teams Global messaging policy)'; Value = $messagingPolicy.AllowSecurityEndUserReporting; Expected = 'True'; Pass = $messagingPolicy.AllowSecurityEndUserReporting -eq $true }
        [pscustomobject]@{ Setting = 'ReportChatMessageEnabled'; Value = $reportPolicy.ReportChatMessageEnabled; Expected = 'False'; Pass = $reportPolicy.ReportChatMessageEnabled -eq $false }
        [pscustomobject]@{ Setting = 'ReportChatMessageToCustomizedAddressEnabled'; Value = $reportPolicy.ReportChatMessageToCustomizedAddressEnabled; Expected = 'True'; Pass = $reportPolicy.ReportChatMessageToCustomizedAddressEnabled -eq $true -and $teamsAddressCheck.Pass }
        [pscustomobject]@{ Setting = 'EnableReportToMicrosoft'; Value = $reportPolicy.EnableReportToMicrosoft; Expected = 'False'; Pass = $reportPolicy.EnableReportToMicrosoft -eq $false }
        [pscustomobject]@{ Setting = 'ReportJunkToCustomizedAddress'; Value = $reportPolicy.ReportJunkToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportJunkToCustomizedAddress -eq $true }
        [pscustomobject]@{ Setting = 'ReportNotJunkToCustomizedAddress'; Value = $reportPolicy.ReportNotJunkToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportNotJunkToCustomizedAddress -eq $true }
        [pscustomobject]@{ Setting = 'ReportPhishToCustomizedAddress'; Value = $reportPolicy.ReportPhishToCustomizedAddress; Expected = 'True'; Pass = $reportPolicy.ReportPhishToCustomizedAddress -eq $true }
    ) + @($destinationChecks)
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
