function Test-MtCheckEidscaAP07 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Guest user access is '2af84b1e-32c8-42b7-82bc-daa82404023b'

    .DESCRIPTION
    Represents role templateId for the role that should be granted to guest user.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .guestUserRoleId with Test-MtEidscaAP07
    and passes when it -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP07',
        Title = 'Default Authorization Settings - Guest user access.',
        Severity = 'High',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP07
    return ($tenantValue -eq '2af84b1e-32c8-42b7-82bc-daa82404023b')
}
