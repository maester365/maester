function Test-MtCheckEidscaAP04 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Guest invite restrictions is one of the following values @('adminsAndGuestInviters','none')

    .DESCRIPTION
    Manages controls who can invite guests to your directory to collaborate on resources secured by your Entra ID (Azure AD), such as SharePoint sites or Azure resources.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .allowInvitesFrom with Test-MtEidscaAP04
    and passes when it -in @('adminsAndGuestInviters','none').
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP04',
        Title = 'Default Authorization Settings - Guest invite restrictions.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP04
    return ($tenantValue -in @('adminsAndGuestInviters','none'))
}
