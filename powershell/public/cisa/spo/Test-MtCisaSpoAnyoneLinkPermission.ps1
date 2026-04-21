function Test-MtCisaSpoAnyoneLinkPermission {
    <#
    .SYNOPSIS
    Checks state of Anyone link permissions for SharePoint Online

    .DESCRIPTION
    Anyone link permissions SHOULD be limited to View only.

    .EXAMPLE
    Test-MtCisaSpoAnyoneLinkPermission

    Returns true if Anyone links are limited to View

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoAnyoneLinkPermission
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SharePoint)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    try {
        $spoTenant = Get-MtSpo

        if ($spoTenant.SharingCapability -ne "ExternalUserAndGuestSharing") {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Anyone links are not enabled. This test only applies when sharing is set to Anyone."
            return $null
        }

        # FileAnonymousLinkType: 1 = View, 2 = Edit
        # FolderAnonymousLinkType: 1 = View, 2 = Edit
        $testResult = $spoTenant.FileAnonymousLinkType -eq 1 -and $spoTenant.FolderAnonymousLinkType -eq 1

        if ($testResult) {
            $testResultMarkdown = "Well done. Anyone link permissions are limited to View only."
        } else {
            $testResultMarkdown = "Anyone link permissions are not limited to View only.`n`n* File Anyone link type: ``$($spoTenant.FileAnonymousLinkType)``  `n* Folder Anyone link type: ``$($spoTenant.FolderAnonymousLinkType)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
