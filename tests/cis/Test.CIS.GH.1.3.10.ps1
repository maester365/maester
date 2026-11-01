function Test-MtCisGitHubNotificationDomainsRestricted {
    <#
    .SYNOPSIS
    CIS.GH.1.3.10: Ensure Source Code Management (SCM) email notifications are restricted to verified domains.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.3.10 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Restricting notification destinations reduces exposure of source-code notifications in personal mailboxes that an attacker could collect remotely.

    .EXAMPLE
    Test-MtCisGitHubNotificationDomainsRestricted

    Assesses CIS.GH.1.3.10 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.3.10
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.3.10',
        Title = 'Ensure Source Code Management (SCM) email notifications are restricted to verified domains',
        Product = 'github',
        Feature = 'enterprise-settings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'High',
        ImplementationCost = 'Medium',
        Mitre = 'T1114.002',
        Control = 'cis-github:1.3.10',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubEnterprise -Purpose Notification
    Add-MtTestResultDetail -Result $evidence.Detail
    switch ($evidence.Verdict) {
        'Passed' { return $true }
        'Failed' { return $false }
        'Indeterminate' {
            Add-MtTestResultDetail -Result $evidence.Detail -SkippedBecause Custom -SkippedCustomReason $evidence.Detail
        }
        'NotApplicable' {
            Add-MtTestResultDetail -Result $evidence.Detail -SkippedBecause NotApplicable
        }
        'Error' { throw $evidence.Detail }
        default { throw 'The GitHub evidence helper returned an unrecognized verdict.' }
    }
}
