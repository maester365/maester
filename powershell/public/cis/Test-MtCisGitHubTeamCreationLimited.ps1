function Test-MtCisGitHubTeamCreationLimited {
    <#
    .SYNOPSIS
    CIS.GH.1.3.2: Ensure team creation is limited to specific members.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.3.2 marks this recommendation as
    Manual. This test automates the organization member-privileges field
    exposed by GET /orgs/{org} and requires members_can_create_teams to be
    false.

    .EXAMPLE
    Test-MtCisGitHubTeamCreationLimited

    Returns true when members cannot create teams.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubTeamCreationLimited
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.3.2.'
        $org = Get-MtGitHubOrganization
        $field = 'members_can_create_teams'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.3.2 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $result = $org.$field -eq $false
        $resultMarkdown = @"
CIS.GH.1.3.2 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
| ``$field`` | ``$($org.$field)`` | ``False`` |
"@
        Add-MtTestResultDetail -Result $resultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
