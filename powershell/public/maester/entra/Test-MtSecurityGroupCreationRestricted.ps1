<#
.SYNOPSIS
    Tests if security group creation is restricted to admin users.
.DESCRIPTION
    This function checks if security group creation is restricted to admin users by querying the authorization policy settings.
.OUTPUTS
    [bool] - Returns $true if security group creation is restricted to admin users, otherwise returns $false.
.EXAMPLE
    Test-MtSecurityGroupCreationRestricted
.LINK
    https://maester.dev/docs/commands/Test-MtSecurityGroupCreationRestricted
#>
function Test-MtSecurityGroupCreationRestricted {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Add the connection check
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Test-MtSecurityGroupCreationRestricted: Checking if security group creation is restricted to admin users..'

    try {
        # Get the authorization policy settings
        $settings = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy?$select=defaultUserRolePermissions' -ApiVersion 'beta' -ErrorAction Stop

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
            $testResultMarkdown = "Well done. Security group creation is restricted to admin users."
        } else {
            $value = 'Yes'
            $status = '❌'
            $testResultMarkdown = "Security group creation is not restricted and non-admin users may be able to create security groups."
        }

        $testResultMarkdown += "`n`n|Setting|Value|Status|`n|---|---|---|`n"
        $testResultMarkdown += "|[Users can create security groups](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/)|$value|$status|"

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $securityGroupCreationRestricted

    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
