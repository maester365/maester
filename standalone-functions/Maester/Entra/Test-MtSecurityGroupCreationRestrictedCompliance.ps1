function Test-MtSecurityGroupCreationRestrictedCompliance {
    <#
    .SYNOPSIS
    Tests if security group creation is restricted to admin users.

    .DESCRIPTION
    This function checks if security group creation is restricted to admin users by querying the authorization policy settings.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtSecurityGroupCreationRestrictedCompliance
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

    Write-Verbose 'Test-MtSecurityGroupCreationRestricted: Checking if security group creation is restricted to admin users..'

    try {
        # Get the authorization policy settings
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authorizationPolicy?$select=defaultUserRolePermissions' -ApiVersion 'beta' -ErrorAction Stop

        # Initialize the result variable
        $securityGroupCreationRestricted = $false

        # Check if defaultUserRolePermissions exists and get the allowedToCreateSecurityGroups setting
        if ($null -ne $settings.defaultUserRolePermissions) {
            $allowedToCreateSecurityGroups = $settings.defaultUserRolePermissions.allowedToCreateSecurityGroups

            # If allowedToCreateSecurityGroups is false, then security group creation is restricted
            $securityGroupCreationRestricted = ($allowedToCreateSecurityGroups -eq $false)
        } else {
            Write-Verbose 'defaultUserRolePermissions not found in authorization policy'
        }

        if ($securityGroupCreationRestricted) {
            $value = 'No'
            $status = '✅'
        } else {
            $value = 'Yes'
            $status = '❌'
        }


        return $securityGroupCreationRestricted

    } catch {
        return $null
    }

}
