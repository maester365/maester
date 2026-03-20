<#
.SYNOPSIS
    Checks if Anyone link permissions are set to view only

.DESCRIPTION
    The allowable file and folder permissions for Anyone links SHALL be set to view only.

    This test is only applicable when the tenant sharing capability is set to Anyone
    (ExternalUserAndGuestSharing). If sharing is more restrictive, Anyone links are not
    available and this control passes automatically.

    Both FileAnonymousLinkType and FolderAnonymousLinkType must be set to View.

.EXAMPLE
    Test-MtCisaSpoAnyoneLinkPermission

    Returns true if Anyone link permissions are view only, or if Anyone sharing is disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoAnyoneLinkPermission
#>
function Test-MtCisaSpoAnyoneLinkPermission {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    # This control only applies when sharing is set to Anyone
    if ($spoTenant.SharingCapability -ne 'ExternalUserAndGuestSharing') {
        $testResultMarkdown = "Well done. SharePoint sharing is not set to Anyone, so Anyone link permissions are not applicable. Current sharing level: **$($spoTenant.SharingCapability)**."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $true
    }

    $fileAnonymousLinkType = $spoTenant.FileAnonymousLinkType
    $folderAnonymousLinkType = $spoTenant.FolderAnonymousLinkType

    $testResult = $fileAnonymousLinkType -eq 'View' -and $folderAnonymousLinkType -eq 'View'

    if ($testResult) {
        $testResultMarkdown = "Well done. Anyone link permissions are set to **View** for both files and folders.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Anyone link permissions are not set to **View** for both files and folders. Both should be set to **View**.`n`n%TestResult%"
    }

    $result = "| Setting | Value | Result |`n"
    $result += "| --- | --- | --- |`n"
    $fileResult = if ($fileAnonymousLinkType -eq 'View') { "Pass" } else { "Fail" }
    $folderResult = if ($folderAnonymousLinkType -eq 'View') { "Pass" } else { "Fail" }
    $result += "| FileAnonymousLinkType | $fileAnonymousLinkType | $fileResult |`n"
    $result += "| FolderAnonymousLinkType | $folderAnonymousLinkType | $folderResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
