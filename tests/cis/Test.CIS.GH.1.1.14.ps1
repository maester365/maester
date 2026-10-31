function Test-MtCisGitHubAdministratorsProtected {
    <#
    .SYNOPSIS
    CIS.GH.1.1.14: Ensure branch protection rules are enforced for administrators.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.1.14 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Applying branch restrictions to privileged accounts reduces the risk that a compromised administrator bypasses software supply-chain controls.

    .EXAMPLE
    Test-MtCisGitHubAdministratorsProtected

    Assesses CIS.GH.1.1.14 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.1.14
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.1.14',
        Title = 'Ensure branch protection rules are enforced for administrators',
        Product = 'github',
        Feature = 'branch-protection',
        Area = 'privileged-access',
        ResourceType = 'Repository',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1195.002',
        Control = 'cis-github:1.1.14',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $evidence = Test-MtCisGitHubBranchEvidence -Control '1.1.14'
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
