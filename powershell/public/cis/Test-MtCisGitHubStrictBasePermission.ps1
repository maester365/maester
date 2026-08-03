function Test-MtCisGitHubStrictBasePermission {
    <#
    .SYNOPSIS
    CIS.GH.1.3.8: Ensure strict base permissions are set for repositories.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 section 1.3.8 marks this recommendation as
    Manual. This test automates the organization default repository permission
    exposed by GET /orgs/{org} and requires the value to be none or read.

    .EXAMPLE
    Test-MtCisGitHubStrictBasePermission

    Returns true when default_repository_permission is none or read.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisGitHubStrictBasePermission
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection GitHub)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGitHub
        return $null
    }

    try {
        Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.3.8.'
        $org = Get-MtGitHubOrganization
        $field = 'default_repository_permission'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.3.8 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $allowedValues = @('none', 'read')
        $actual = [string]$org.$field
        $result = $allowedValues -contains $actual
        $resultMarkdown = @"
CIS.GH.1.3.8 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
| ``$field`` | ``$actual`` | ``none`` or ``read`` |
"@
        Add-MtTestResultDetail -Result $resultMarkdown
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
