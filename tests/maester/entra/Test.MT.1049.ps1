function Test-MtCheckMT1049 {
    <#
    .SYNOPSIS
    Conditional Access policies for User Risk and Sign-in Risk should be configured separately.

    .DESCRIPTION
    Runs the shared check Test-MtCaMisconfiguredIDProtection.
    #>
    [MaesterTest(
        Id = 'MT.1049',
        Title = 'Conditional Access policies for User Risk and Sign-in Risk should be configured separately.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'Maester'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'BakkerJan',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCaMisconfiguredIDProtection
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
