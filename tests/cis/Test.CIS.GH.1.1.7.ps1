function Test-MtCisGitHubCodeOwnerReviewRequired {
    <#
    .SYNOPSIS
    CIS.GH.1.1.7: Ensure code owner's review is required when a change affects owned code.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.7 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Requiring designated owners to approve changes to owned code adds a review barrier against malicious software supply-chain changes.

    .EXAMPLE
    Test-MtCisGitHubCodeOwnerReviewRequired

    Assesses CIS.GH.1.1.7 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.7
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.7',
        Title = 'Ensure code owner''s review is required when a change affects owned code',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.7',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.7'
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
