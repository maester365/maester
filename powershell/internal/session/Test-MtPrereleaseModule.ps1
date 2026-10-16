function Test-MtPrereleaseModule {
    <#
    .SYNOPSIS
    Returns $true when the loaded Maester module is a preview (its manifest has a Prerelease label).

    .DESCRIPTION
    A preview has the version number of the release it leads to, so the module version alone cannot tell
    3.0.0-preview2 from 3.0.0. The label is in the manifest's PrivateData.PSData.Prerelease.

    .EXAMPLE
    Test-MtPrereleaseModule
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $module = $MyInvocation.MyCommand.Module
    if (-not $module -or -not $module.PrivateData) { return $false }
    $psData = $module.PrivateData['PSData']
    return [bool]($psData -and "$($psData['Prerelease'])".Trim())
}
