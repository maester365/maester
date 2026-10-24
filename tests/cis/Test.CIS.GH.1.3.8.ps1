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
    [MaesterTest(
        Id = 'CIS.GH.1.3.8',
        Title = 'Ensure strict base permissions are set for repositories',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1677', 'T1195.002'),
        Control = ('cis-github:1.3.8', 'nist-800-53-r5:AC-6', 'nist-800-53-r5:AC-3'),
        Service = 'GitHub',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Retrieving GitHub organization settings for CIS.GH.1.3.8.'
    $org = Get-MtGitHubOrganization
    $field = 'default_repository_permission'
    if (-not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName $field)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization response did not include required field '$field'. This field is required to evaluate CIS.GH.1.3.8 and may be missing because of permissions, plan, API version, or organization type."
        return $null
    }

    $actual = $org.$field
    $recognizedValues = @('none', 'read', 'write', 'admin')
    if ($actual -isnot [string] -or $recognizedValues -notcontains $actual) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: GitHub organization field '$field' must be a recognized permission string (none, read, write, or admin) to evaluate CIS.GH.1.3.8. No configuration verdict was produced."
        return $null
    }

    $allowedValues = @('none', 'read')
    $result = $allowedValues -contains $actual
    $resultSummary = if ($result) {
        'Well done. Organization base permissions are limited to none or read.'
    } else {
        'Organization base permissions grant write or administrator access. Set Base permissions to None or Read and review explicit access grants.'
    }
    $resultMarkdown = @"
$resultSummary

CIS.GH.1.3.8 automated evidence from ``GET /orgs/{org}``.

| Field | Actual | Expected |
| --- | --- | --- |
| ``$field`` | ``$actual`` | ``none`` or ``read`` |
"@
    Add-MtTestResultDetail -Result $resultMarkdown
    return $result
}
