function Test-MtCisGitHubOrganizationVerified {
    <#
    .SYNOPSIS
    CIS.GH.1.3.9: Ensure an organization’s identity is confirmed with a “Verified” badge.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.3.9 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. A verified profile helps distinguish an organization from an attacker masquerading as it.

    .EXAMPLE
    Test-MtCisGitHubOrganizationVerified

    Assesses CIS.GH.1.3.9 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.3.9
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.3.9',
        Title = 'Ensure an organization’’s identity is confirmed with a “Verified” badge',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1684.001',
        Control = 'cis-github:1.3.9',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubOrganizationVerification
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
