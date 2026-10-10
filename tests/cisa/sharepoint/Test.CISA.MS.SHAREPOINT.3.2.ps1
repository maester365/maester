function Test-MtCisaSpoAnyoneLinkPermission {
    <#
    .SYNOPSIS
    Checks state of Anyone link permissions for SharePoint Online

    .DESCRIPTION
    Anyone link permissions SHALL be limited to View only.

    .EXAMPLE
    Test-MtCisaSpoAnyoneLinkPermission

    Returns true if Anyone links are limited to View

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoAnyoneLinkPermission
    #>
    [MaesterTest(
        Id = 'CISA.MS.SHAREPOINT.3.2',
        Title = 'Allowable file and folder permissions for Anyone links SHALL be set to View only.',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'SharePoint',
        Tag = ('MS.SHAREPOINT', 'MS.SHAREPOINT.3.2'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($spoTenant.SharingCapability -ne "ExternalUserAndGuestSharing") {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Anyone links are not enabled. This test only applies when sharing is set to Anyone."
        return $null
    }

    $testResult = $spoTenant.FileAnonymousLinkType -eq 'View' -and $spoTenant.FolderAnonymousLinkType -eq 'View'

    if ($testResult) {
        $testResultMarkdown = "Well done. Anyone link permissions are limited to View only."
    } else {
        $testResultMarkdown = "Anyone link permissions are not limited to View only.`n`n* File Anyone link type: ``$($spoTenant.FileAnonymousLinkType)``  `n* Folder Anyone link type: ``$($spoTenant.FolderAnonymousLinkType)``"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity Medium

    return $testResult
}
