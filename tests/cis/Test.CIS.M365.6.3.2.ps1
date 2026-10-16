function Test-MtCisPersonalAccountsDisabledInOutlook {
    <#
    .SYNOPSIS
        Checks that the default OWA policy does not allow connecting personal email accounts and calendars.

    .DESCRIPTION
        Checks the default Outlook on the web mailbox policy and passes when users cannot connect personal email accounts and personal calendars to Outlook.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.3.2, L1)

    .EXAMPLE
        Test-MtCisPersonalAccountsDisabledInOutlook

        Returns true if personal accounts and calendars cannot be added to Outlook.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.3.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.3.2',
        Title = 'Ensure the ability to add personal email accounts and calendars is disabled',
        Product = 'exchange',
        Feature = 'outlook',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:6.3.2', 'nist-800-53-r5:AC-20'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $owaPolicy = @(Get-MtExo -Request OwaMailboxPolicy) | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1

    $checks = @(
        [pscustomobject]@{ Setting = 'PersonalAccountsEnabled'; Value = $(if ($null -eq ($owaPolicy.PersonalAccountsEnabled)) { 'Not found' } else { $owaPolicy.PersonalAccountsEnabled }); Pass = [bool]($owaPolicy.PersonalAccountsEnabled -eq $false) }
        [pscustomobject]@{ Setting = 'PersonalAccountCalendarsEnabled'; Value = $(if ($null -eq ($owaPolicy.PersonalAccountCalendarsEnabled)) { 'Not found' } else { $owaPolicy.PersonalAccountCalendarsEnabled }); Pass = [bool]($owaPolicy.PersonalAccountCalendarsEnabled -eq $false) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Personal email accounts and calendars cannot be connected to Outlook.'
    $failText = 'Users can connect personal email accounts or calendars to Outlook.'

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
