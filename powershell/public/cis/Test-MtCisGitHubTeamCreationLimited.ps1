function Test-MtCisGitHubTeamCreationLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.3.2: Ensure team creation is limited to specific members.
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
        $field = 'members_can_create_teams'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.3.2 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $result = $org.$field -eq $false
        Add-MtTestResultDetail -Result "CIS.GH.1.3.2 automated evidence from ``GET /orgs/{org}``: ``$field`` is ``$($org.$field)``. Expected value: ``False``."
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
