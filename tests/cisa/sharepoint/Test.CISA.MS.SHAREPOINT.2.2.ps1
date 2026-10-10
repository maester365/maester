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
    [MaesterTest(
        Id = 'CISA.MS.SHAREPOINT.2.2',
        Title = 'File and folder default sharing permissions SHALL be set to View only.',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'SharePoint',
        Tag = ('MS.SHAREPOINT', 'MS.SHAREPOINT.2.2'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    # DefaultLinkPermission: None = not explicitly set, View = View only, Edit = Edit
    # CISA requires an explicit View choice — None (never set) should fail.
    $testResult = $spoTenant.DefaultLinkPermission -eq 'View'

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant default sharing permission is set to View."
    } else {
        $testResultMarkdown = "Your tenant default sharing permission is not set to View.`n`n* Current setting: ``$($spoTenant.DefaultLinkPermission)``"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity Low

    return $testResult
}
