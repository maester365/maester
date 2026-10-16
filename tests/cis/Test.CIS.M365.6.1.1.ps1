function Test-MtCisOrganizationAuditEnabled {
    <#
    .SYNOPSIS
        Checks that mailbox auditing is not disabled for the organization.

    .DESCRIPTION
        Checks the Exchange Online organisation configuration and passes when AuditDisabled is false, so that mailbox auditing is on by default for every mailbox.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.1.1, L1)

    .EXAMPLE
        Test-MtCisOrganizationAuditEnabled

        Returns true if mailbox auditing is not disabled for the organization.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.1.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.1.1',
        Title = 'Ensure ''AuditDisabled'' organizationally is set to ''False''',
        Product = 'exchange',
        Feature = 'mailbox-auditing',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1685.002',
        Control = ('cis-m365:6.1.1', 'nist-800-53-r5:AU-12'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $orgConfig = Get-MtExo -Request OrganizationConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'AuditDisabled'; Value = $(if ($null -eq ($orgConfig.AuditDisabled)) { 'Not found' } else { $orgConfig.AuditDisabled }); Pass = [bool]($orgConfig.AuditDisabled -eq $false) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Mailbox auditing is not disabled for the organization.'
    $failText = 'Mailbox auditing is disabled for the organization.'

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
