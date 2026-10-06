function Test-MtTenantCreationRestricted {
    <#
    .SYNOPSIS
    Tests if Entra ID tenant creation is restricted to admin users.
    .DESCRIPTION
    This function checks if the Entra ID tenant creation is restricted to admin users by querying the authorization policy settings.
    .OUTPUTS
    [bool] - Returns $true if tenant creation is restricted to admin users, otherwise returns $false.
    .EXAMPLE
    Test-MtTenantCreationRestricted
    .LINK
    https://maester.dev/docs/commands/Test-MtTenantCreationRestricted
    #>
    [MaesterTest(
        Id = 'MT.1068',
        Title = 'Restrict non-admin users from creating tenants.',
        Severity = 'Medium',
        Category = 'Maester/Entra',
        Tag = ('Entra', 'Maester'),
        Service = 'Graph',
        Author = 'marcel-ngn'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Add the connection check

    Write-Verbose 'Test-MtTenantCreationRestricted: Checking if tenant creation is restricted to admin users..'

    # Get the authorization policy settings
    $settings = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy?$select=defaultUserRolePermissions' -ApiVersion 'beta' -ErrorAction Stop

    # Initialize the result variable
    $tenantCreationRestricted = $false

    # Check if defaultUserRolePermissions exists and get the allowedToCreateTenants setting
    if ($null -ne $settings.defaultUserRolePermissions) {
        $allowedToCreateTenants = $settings.defaultUserRolePermissions.allowedToCreateTenants

        # If allowedToCreateTenants is false, then tenant creation is restricted
        $tenantCreationRestricted = ($allowedToCreateTenants -eq $false)
    } else {
        Write-Verbose 'defaultUserRolePermissions not found in authorization policy'
    }

    if ($tenantCreationRestricted) {
        $value = 'Yes'
        $status = '✅'
        $testResultMarkdown = "Well done. Entra ID tenant creation is restricted to admin users."
    } else {
        $value = 'No'
        $status = '❌'
        $testResultMarkdown = "Entra ID tenant creation is not restricted and non-admin users may be able to create tenants."
    }

    $testResultMarkdown += "`n`n"
    $testResultMarkdown += "| Setting | Value | Status |`n"
    $testResultMarkdown += "|---------|-------|-------|`n"
    $testResultMarkdown += "| [Restrict non-admin users from creating tenants](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/) | $value | $status |`n"

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantCreationRestricted

}
