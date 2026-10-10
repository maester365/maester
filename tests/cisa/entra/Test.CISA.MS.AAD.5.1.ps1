function Test-MtCisaAppRegistration {
    <#
    .SYNOPSIS
    Checks if user app registration is prevented

    .DESCRIPTION
    Only administrators SHALL be allowed to register applications.

    .EXAMPLE
    Test-MtCisaAppRegistration

    Returns true if disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAppRegistration
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.5.1',
        Title = 'Only administrators SHALL be allowed to register applications.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Entra ID',
        Tag = ('Entra ID Free', 'MS.AAD', 'MS.AAD.5.1'),
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $testResult = $result.defaultUserRolePermissions.allowedToCreateApps -eq $false

    if ($testResult) {
        $testResultMarkdown = "Well done. **[Users can register applications](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings)** is set to **No** in your tenant."
    } else {
        $testResultMarkdown = "Your tenant is configured with **[Users can register applications](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings)** set to **Yes**. The recommended setting is **No**."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
