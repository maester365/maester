function Test-MtCheckEidscaPR05 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds is greater than or equal to 60

    .DESCRIPTION
    The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaPR05
    and passes when it -ge 60.
    #>
    [MaesterTest(
        Id = 'EIDSCA.PR05',
        Title = 'Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaPR05
    return ($tenantValue -ge 60)
}
