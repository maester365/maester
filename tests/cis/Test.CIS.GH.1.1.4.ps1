function Test-MtCisGitHubStaleApprovalsDismissed {
    <#
    .SYNOPSIS
    CIS.GH.1.1.4: Ensure previous approvals are dismissed when updates are introduced to a code change proposal.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.4 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Dismiss stale approvals after reviewable changes so an attacker cannot reuse an earlier approval to insert unreviewed code into the software supply chain.

    .EXAMPLE
    Test-MtCisGitHubStaleApprovalsDismissed

    Assesses CIS.GH.1.1.4 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.4
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.4',
        Title = 'Ensure previous approvals are dismissed when updates are introduced to a code change proposal',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.4',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.4'
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
