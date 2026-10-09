function Test-MtCheckEidscaCR01 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature is 'true'

    .DESCRIPTION
    Defines if admin consent request feature is enabled or disabled

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy
    .isEnabled with Test-MtEidscaCR01
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CR01',
        Title = 'Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaCR01
    return ($tenantValue -eq 'true')
}
