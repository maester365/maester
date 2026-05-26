function Test-MtTenantCreationRestrictedCompliance {
    <#
    .SYNOPSIS
    Tests if Entra ID tenant creation is restricted to admin users.

    .DESCRIPTION
    This function checks if the Entra ID tenant creation is restricted to admin users by querying the authorization policy settings.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtTenantCreationRestrictedCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    # Add the connection check

    Write-Verbose 'Test-MtTenantCreationRestricted: Checking if tenant creation is restricted to admin users..'

    try {
        # Get the authorization policy settings
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy?$select=defaultUserRolePermissions' -ApiVersion 'beta' -ErrorAction Stop

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
        } else {
            $value = 'No'
            $status = '❌'
        }


        return $tenantCreationRestricted

    } catch {
        return $null
    }

}
