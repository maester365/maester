function Test-MtCisExternalSenderIdentification {
    <#
    .SYNOPSIS
        Checks that Outlook shows an external sender tag.

    .DESCRIPTION
        Checks the external sender identification setting in Exchange Online and passes when it is enabled, so that Outlook shows an External tag on messages that come from outside the organisation.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.2.3, L1)

    .EXAMPLE
        Test-MtCisExternalSenderIdentification

        Returns true if external sender identification is enabled.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.2.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.2.3',
        Title = 'Ensure email from external senders is identified',
        Product = 'exchange',
        Feature = 'outlook',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:6.2.3', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $externalInOutlook = Get-MtExo -Request ExternalInOutlook

    $checks = @(
        [pscustomobject]@{ Setting = 'External sender identification enabled'; Value = $(if ($null -eq ($externalInOutlook.Enabled)) { 'Not found' } else { $externalInOutlook.Enabled }); Pass = [bool]($externalInOutlook.Enabled -eq $true) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'External sender identification is enabled.'
    $failText = 'External sender identification is not enabled.'

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
