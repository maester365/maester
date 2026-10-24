function Test-MtCisGitHubForcePushDenied {
    <#
    .SYNOPSIS
    CIS.GH.1.1.16: Ensure force push code to branches is denied.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.16 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Blocking force pushes helps prevent an attacker from rewriting reviewed source history and introducing malicious software supply-chain changes.

    .EXAMPLE
    Test-MtCisGitHubForcePushDenied

    Assesses CIS.GH.1.1.16 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.16
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.16',
        Title = 'Ensure force push code to branches is denied',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'engineering-systems',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.16',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.16'
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
