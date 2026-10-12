function Test-MtCheckEidscaPR02 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory is 'True'

    .DESCRIPTION
    If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaPR02
    and passes when it -eq 'True'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.PR02',
        Title = 'Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory.',
        Product = 'entra',
        RelatedProduct = 'ad',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Control = 'nist-800-53-r5:IA-5(1)',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaPR02
    return ($tenantValue -eq 'True')
}
