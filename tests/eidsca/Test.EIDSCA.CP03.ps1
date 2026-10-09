function Test-MtCheckEidscaCP03 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Block user consent for risky apps is 'true'

    .DESCRIPTION
    Defines whether user consent will be blocked when a risky request is detected

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaCP03
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.CP03',
        Title = 'Default Settings - Consent Policy Settings - Block user consent for risky apps.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaCP03
    return ($tenantValue -eq 'true')
}
