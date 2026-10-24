function Test-MtCisGitHubRepositoryDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.3: Ensure repository deletion is limited to specific users.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.2.3 marks this recommendation as
    Manual. This test collects organization setting evidence from
    GET /orgs/{org} and marks the result as Investigate because CIS GH 1.2.3
    still requires a manual trust review for either repository administrators
    or organization owners.

    .EXAMPLE
    Test-MtCisGitHubRepositoryDeletionLimited

    Returns Investigate when the GitHub organization setting is a Boolean;
    unusable evidence is indeterminate.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubRepositoryDeletionLimited
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.2.3',
        Title = 'Ensure repository deletion is limited to specific users',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1485', 'T1070'),
        Control = ('cis-github:1.2.3', 'nist-800-53-r5:AC-6'),
        Service = 'GitHub',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.2.3.'
    $org = Get-MtGitHubOrganization
    $field = 'members_can_delete_repositories'
    if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.2.3 and may be missing because of permissions, plan, API version, or organization type."
        return $null
    }

    if ($org.$field -isnot [bool]) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization field '$field' must be a Boolean to evaluate CIS.GH.1.2.3. No configuration verdict was produced."
        return $null
    }

    $resultMarkdown = @"
CIS.GH.1.2.3 automated evidence from ``GET /orgs/{org}``.

| Field | Actual |
| --- | --- |
| ``$field`` | ``$($org.$field)`` |

Partial evidence only: this setting does not establish CIS compliance. The administrator/owner population and trust review below remains unassessed.
"@

    if ($org.$field -eq $true) {
        $resultMarkdown += @"

Manual review required - ``members_can_delete_repositories`` is true. For CIS GH 1.2.3, verify that every repository has exactly two repository administrators, both trusted and qualified; document the population and trust review.
"@
    } else {
        $resultMarkdown += @"

Manual review required - ``members_can_delete_repositories`` is false. For CIS GH 1.2.3, verify that there are only a few organization owners, all trusted and qualified; document the population and trust review. CIS does not specify a numeric owner limit.
"@
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Investigate
    return $null
}
