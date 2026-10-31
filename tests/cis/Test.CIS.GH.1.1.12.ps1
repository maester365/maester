function Test-MtCisGitHubSignedCommitsRequired {
    <#
    .SYNOPSIS
    CIS.GH.1.1.12: Ensure verification of signed commits for new changes before merging.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.12 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. GitHub signature requirements help prevent an attacker from introducing software supply-chain changes using unsigned commits.

    .EXAMPLE
    Test-MtCisGitHubSignedCommitsRequired

    Assesses CIS.GH.1.1.12 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.12
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.12',
        Title = 'Ensure verification of signed commits for new changes before merging',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'High',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.12',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.12'
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
