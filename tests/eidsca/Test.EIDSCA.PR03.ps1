function Test-MtCheckEidscaPR03 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Enforce custom list is 'True'

    .DESCRIPTION
    When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaPR03
    and passes when it -eq 'True'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.PR03',
        Title = 'Default Settings - Password Rule Settings - Enforce custom list.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaPR03
    return ($tenantValue -eq 'True')
}
