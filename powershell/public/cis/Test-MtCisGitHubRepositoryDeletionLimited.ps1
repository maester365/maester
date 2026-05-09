function Test-MtCisGitHubRepositoryDeletionLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.2.3: Ensure repository deletion is limited to specific users.

    .DESCRIPTION
    Implements the strict automated setting-based interpretation by requiring
    members_can_delete_repositories to be false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        $org = Get-MtGitHubOrganization
        $field = 'members_can_delete_repositories'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.2.3 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $result = $org.$field -eq $false
        Add-MtTestResultDetail -Result "CIS.GH.1.2.3 automated evidence from ``GET /orgs/{org}``: ``$field`` is ``$($org.$field)``. Expected strict automated value: ``False``."
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
