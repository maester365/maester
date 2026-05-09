function Test-MtCisGitHubStrictBasePermission {
    <#
    .SYNOPSIS
    CIS.GH.1.3.8: Ensure strict base permissions are set for repositories.
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
        $field = 'default_repository_permission'
        if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.3.8 and may be missing because of permissions, plan, API version, or organization type."
            return $null
        }

        $allowedValues = @('none', 'read')
        $actual = [string]$org.$field
        $result = $allowedValues -contains $actual
        Add-MtTestResultDetail -Result "CIS.GH.1.3.8 automated evidence from ``GET /orgs/{org}``: ``$field`` is ``$actual``. Expected value: ``none`` or ``read``."
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
