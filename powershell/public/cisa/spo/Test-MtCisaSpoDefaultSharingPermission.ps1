function Test-MtCisaSpoDefaultSharingPermission {
    <#
    .SYNOPSIS
    Checks state of default SharePoint Online sharing permission

    .DESCRIPTION
    Default file and folder sharing permission SHOULD be set to View.

    .EXAMPLE
    Test-MtCisaSpoDefaultSharingPermission

    Returns true if default sharing permission is set to View

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoDefaultSharingPermission
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

        # DefaultLinkPermission: None = not explicitly set, View = View only, Edit = Edit
        # CISA requires an explicit View choice — None (never set) should fail.
        $testResult = $spoTenant.DefaultLinkPermission -eq "View"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant default sharing permission is set to View."
        } else {
            $testResultMarkdown = "Your tenant default sharing permission is not set to View.`n`n* Current setting: ``$($spoTenant.DefaultLinkPermission)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
