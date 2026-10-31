function Test-MtCisGitHubConversationsResolved {
    <#
    .SYNOPSIS
    CIS.GH.1.1.11: Ensure all open comments are resolved before allowing code change merging.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.11 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Resolving review conversations ensures that concerns about a software supply-chain change are acknowledged before merging.

    .EXAMPLE
    Test-MtCisGitHubConversationsResolved

    Assesses CIS.GH.1.1.11 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.11
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.11',
        Title = 'Ensure all open comments are resolved before allowing code change merging',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.11',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.11'
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
