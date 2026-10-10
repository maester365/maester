function Test-MtCheckEidscaAP05 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Sign-up for email based subscription is 'false'

    .DESCRIPTION
    Indicates whether users can sign up for email based subscriptions.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .allowedToSignUpEmailBasedSubscriptions with Test-MtEidscaAP05
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP05',
        Title = 'Default Authorization Settings - Sign-up for email based subscription.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP05
    return ($tenantValue -eq 'false')
}
