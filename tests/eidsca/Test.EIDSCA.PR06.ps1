function Test-MtCheckEidscaPR06 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold is less than or equal to 10

    .DESCRIPTION
    How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaPR06
    and passes when it -le 10.
    #>
    [MaesterTest(
        Id = 'EIDSCA.PR06',
        Title = 'Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaPR06
    return ($tenantValue -le 10)
}
