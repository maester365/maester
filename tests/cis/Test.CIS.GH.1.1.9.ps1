function Test-MtCisGitHubStatusChecksRequired {
    <#
    .SYNOPSIS
    CIS.GH.1.1.9: Ensure all checks have passed before merging new code.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.9 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Required checks add a quality and security gate before a malicious software supply-chain change can be merged.

    .EXAMPLE
    Test-MtCisGitHubStatusChecksRequired

    Assesses CIS.GH.1.1.9 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.9
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.9',
        Title = 'Ensure all checks have passed before merging new code',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.9',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.9'
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
