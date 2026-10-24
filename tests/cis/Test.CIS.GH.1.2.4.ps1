function Test-MtCisGitHubIssueDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.4: Ensure issue deletion is limited to specific users.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.2.4 marks this recommendation as
    Manual. This test collects organization setting evidence from
    GET /orgs/{org} and marks the result as Investigate because CIS GH 1.2.4
    still requires a manual trust review for either repository administrators
    or organization owners.

    .EXAMPLE
    Test-MtCisGitHubIssueDeletionLimited

    Returns Investigate when the GitHub organization setting is a Boolean;
    unusable evidence is indeterminate.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubIssueDeletionLimited
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.2.4',
        Title = 'Ensure issue deletion is limited to specific users',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1070', 'T1485'),
        Control = ('cis-github:1.2.4', 'nist-800-53-r5:AC-6'),
        Service = 'GitHub',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.2.4.'
    $org = Get-MtGitHubOrganization
    $field = 'members_can_delete_issues'
    if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.2.4 and may be missing because of permissions, plan, API version, or organization type."
        return $null
    }

    if ($org.$field -isnot [bool]) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization field '$field' must be a Boolean to evaluate CIS.GH.1.2.4. No configuration verdict was produced."
        return $null
    }

    $resultMarkdown = @"
CIS.GH.1.2.4 automated evidence from ``GET /orgs/{org}``.

| Field | Actual |
| --- | --- |
| ``$field`` | ``$($org.$field)`` |

Partial evidence only: this setting does not establish CIS compliance. The administrator/owner population and trust review below remains unassessed.
"@

    if ($org.$field -eq $true) {
        $resultMarkdown += @"

Manual review required - ``members_can_delete_issues`` is true. For CIS GH 1.2.4, verify that every repository has exactly two repository administrators, both trusted and qualified; document the population and trust review.
"@
    } else {
        $resultMarkdown += @"

Manual review required - ``members_can_delete_issues`` is false. For CIS GH 1.2.4, verify that there are only a few organization owners, all trusted and qualified; document the population and trust review. CIS does not specify a numeric owner limit.
"@
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Investigate
    return $null
}
