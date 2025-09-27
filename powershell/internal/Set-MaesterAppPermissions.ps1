<#
    .SYNOPSIS
    Internal helper function to set Graph API permissions for a Maester application.

    .DESCRIPTION
    This function configures the required Graph API permissions (app roles) for a Maester application
    in Azure AD/Entra ID. It handles both creating new permissions and updating existing ones.

    .PARAMETER ApplicationId
    The Application (Client) ID of the app to configure permissions for.

    .PARAMETER Scopes
    Array of Graph API permission scopes to configure for the application.

    .EXAMPLE
    Set-MaesterAppPermissions -ApplicationId "12345678-1234-1234-1234-123456789012" -Scopes @("Directory.Read.All", "Policy.Read.All")
#>
function Set-MaesterAppPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ApplicationId,

        [Parameter(Mandatory = $true)]
        [string[]] $Scopes
    )

    Write-Verbose "Setting permissions for app: $ApplicationId"
    Write-Verbose "Scopes: $($Scopes -join ', ')"

    try {
        # Get the service principal for the app
        $appSPResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$ApplicationId'" -Method GET
        $appSPs = ($appSPResponse.Content | ConvertFrom-Json).value

        if ($appSPs.Count -eq 0) {
            throw "Service principal for application not found. Ensure the application has a service principal."
        }

        # Get the Microsoft Graph service principal
        $graphSPResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/beta/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'" -Method GET
        $graphSP = ($graphSPResponse.Content | ConvertFrom-Json).value
        if ($graphSP.Count -eq 0) {
            throw "Microsoft Graph service principal not found."
        }

        $appSP = $appSPs[0]

        # Get current app role assignments for the service principal
        $currentAssignments = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($appSP.id)/appRoleAssignments" -Method GET
        $currentAppRoles = ($currentAssignments.Content | ConvertFrom-Json).value

        # Get all available Graph app roles
        $graphAppRoles = $graphSP.appRoles

        # Process each requested scope
        foreach ($scope in $Scopes) {
            Write-Verbose "Processing scope: $scope"

            # Find the app role for this scope
            $appRole = $graphAppRoles | Where-Object { $_.value -eq $scope }

            if (-not $appRole) {
                Write-Warning "App role '$scope' not found in Microsoft Graph service principal"
                continue
            }

            # Check if permission already exists
            $existingPermission = $currentAppRoles | Where-Object { $_.appRoleId -eq $appRole.id -and $_.resourceId -eq $graphSP.id }

            if ($existingPermission) {
                Write-Verbose "Permission '$scope' already exists"
                continue
            }

            # Add the permission
            $permissionBody = @{
                principalId = $appSP.id
                resourceId = $graphSP.id
                appRoleId = $appRole.id
            } | ConvertTo-Json

            Write-Verbose "Adding permission: $scope"
            $response = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($appSP.id)/appRoleAssignments" -Method POST -Payload $permissionBody

            if ($response.StatusCode -ne 201) {
                Write-Warning "Failed to add permission '$scope'. Status: $($response.StatusCode)"
            } else {
                Write-Verbose "Successfully added permission: $scope"
            }
        }
    }
    catch {
        Write-Error "Failed to set permissions for app $ApplicationId : $($_.Exception.Message)"
        throw
    }
}