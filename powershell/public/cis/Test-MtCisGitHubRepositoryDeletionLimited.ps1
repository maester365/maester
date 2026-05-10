function Test-MtCisGitHubRepositoryDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.3: Ensure repository deletion is limited to specific users.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.2.3 marks this recommendation as
    Manual. This test automates the organization member-privileges field
    exposed by GET /orgs/{org}. By default, Maester uses a strict automated
    interpretation and requires members_can_delete_repositories to be false.
    If GitHubAllowMemberRepositoryDeletion is literal boolean true in
    maester-config.json, a true value is reported as requiring manual review
    instead of a hard failure.

    .EXAMPLE
    Test-MtCisGitHubRepositoryDeletionLimited

    Returns true when members cannot delete repositories.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubRepositoryDeletionLimited
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.2.3.'
        $org = Get-MtGitHubOrganization
        $field = 'members_can_delete_repositories'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.2.3 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $result = $org.$field -eq $false
        $resultMarkdown = @"
CIS.GH.1.2.3 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
| ``$field`` | ``$($org.$field)`` | ``False`` |
"@
        $allowManualReview = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubAllowMemberRepositoryDeletion'
        $manualReviewAllowed = $allowManualReview -is [bool] -and $allowManualReview -eq $true
        if (-not $result -and $manualReviewAllowed) {
            $resultMarkdown += @"

Manual review required - ``members_can_delete_repositories`` is true. CIS GH 1.2.3 audit requires verifying repository admin members are trusted and qualified; document the review.
"@
            Add-MtTestResultDetail -Result $resultMarkdown -Investigate
            return $null
        }

        Add-MtTestResultDetail -Result $resultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
