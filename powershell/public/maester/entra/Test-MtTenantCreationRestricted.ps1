function Test-MtTenantCreationRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Add the connection check
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Test-MtTenantCreationRestricted: Checking if tenant creation is restricted to admin users..'

    try {
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
            $testResultMarkdown = "Well done. Entra ID tenant creation is restricted to admin users."
            Add-MtTestResultDetail -Result $testResultMarkdown
        } else {
            $testResultMarkdown = "Entra ID tenant creation is not restricted and non-admin users may be able to create tenants."
            Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType AuthorizationPolicy -GraphObjects $settings
        }

        return $tenantCreationRestricted

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}