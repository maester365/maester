function Test-MtCheckEidscaCP04 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to is 'true'

    .DESCRIPTION
    If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaCP04
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CP04',
        Title = 'Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaCP04
    return ($tenantValue -eq 'true')
}
