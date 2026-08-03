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

    Returns Investigate when the GitHub organization setting is available.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubIssueDeletionLimited
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.2.4.'
        $org = Get-MtGitHubOrganization
        $field = 'members_can_delete_issues'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.2.4 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $resultMarkdown = @"
CIS.GH.1.2.4 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
| ``$field`` | ``$($org.$field)`` | ``False`` |
"@

        if ($org.$field -eq $true) {
            $resultMarkdown += @"

Manual review required - ``members_can_delete_issues`` is true. CIS GH 1.2.4 audit requires verifying repository admin members are trusted and qualified; document the review.
"@
        } else {
            $resultMarkdown += @"

Manual review required - ``members_can_delete_issues`` is false. CIS GH 1.2.4 audit still requires verifying organization owners are trusted and qualified; document the review.
"@
        }

        Add-MtTestResultDetail -Result $resultMarkdown -Investigate
        return $null
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
