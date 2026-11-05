function Test-MtCisGitHubDefaultBranchProtected {
    <#
    .SYNOPSIS
    CIS.GH.1.1.20: Ensure branch protection is enforced on the default branch.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.20 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Protecting the default and main branches provides a policy boundary against unauthorized software supply-chain changes.

    .EXAMPLE
    Test-MtCisGitHubDefaultBranchProtected

    Assesses CIS.GH.1.1.20 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.20
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.20',
        Title = 'Ensure branch protection is enforced on the default branch',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.20',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.20'
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
