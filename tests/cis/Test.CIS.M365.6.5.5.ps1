function Test-MtCisDirectSendRejected {
    <#
    .SYNOPSIS
        Checks that Exchange Online rejects Direct Send submissions.

    .DESCRIPTION
        Checks the Exchange Online organisation configuration and passes when RejectDirectSend is true, so that unauthenticated messages to your own domain over the MX endpoint that claim to come from internal senders are rejected.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.5.5, L2)

    .EXAMPLE
        Test-MtCisDirectSendRejected

        Returns true if Direct Send submissions are rejected.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.5.5
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.5.5',
        Title = 'Ensure Direct Send submissions are rejected',
        Product = 'exchange',
        Feature = 'mail-flow',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:6.5.5', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $orgConfig = Get-MtExo -Request OrganizationConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'RejectDirectSend'; Value = $(if ($null -eq ($orgConfig.RejectDirectSend)) { 'Not found' } else { $orgConfig.RejectDirectSend }); Pass = [bool]($orgConfig.RejectDirectSend -eq $true) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Direct Send submissions are rejected.'
    $failText = 'Direct Send submissions are not rejected.'

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
