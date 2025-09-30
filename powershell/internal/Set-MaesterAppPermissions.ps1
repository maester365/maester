<#
    .SYNOPSIS
    Internal helper function to set Graph API permissions for a Maester application.

    .DESCRIPTION
    This function configures the required Graph API permissions (app roles) for a Maester application
    in Azure AD/Entra ID. It handles both creating new permissions and updating existing ones.

    .PARAMETER AppId
    The Application (Client) ID of the app to configure permissions for.

    .PARAMETER Scopes
    Array of Graph API permission scopes to configure for the application.

    .EXAMPLE
    Set-MaesterAppPermission -AppId "12345678-1234-1234-1234-123456789012" -Scopes @("Directory.Read.All", "Policy.Read.All")
#>
function Set-MaesterAppPermission {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $AppId,

        [Parameter(Mandatory = $true)]
        [string[]] $Scopes
    )

    process {
        Write-Verbose "Setting permissions for app: $AppId"
        Write-Verbose "Scopes: $($Scopes -join ', ')"

        # Get the service principal for the app
        $appSPResponse = Invoke-MtAzureRequest -RelativeUri "servicePrincipals" -Filter "appId eq '$AppId'" -Method GET -Graph
        $appSPs = $appSPResponse.value

        if ($appSPs.Count -eq 0) {
            throw "Service principal for application not found. Try deleting the Maester app and recreating with New-MtMaesterApp."
        }

        # Get the Microsoft Graph service principal
        $graphSPResponse = Invoke-MtAzureRequest -RelativeUri "servicePrincipals" -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Method GET -Graph
        $graphSPResults = $graphSPResponse.value
        if ($graphSPResults.Count -eq 0) {
            throw "Microsoft Graph service principal not found."
        }

        $appSP = $appSPs[0]
        $graphSP = $graphSPResults[0]

        # Get current app role assignments for the service principal
        $currentAssignments = Invoke-MtAzureRequest -RelativeUri "servicePrincipals/$($appSP.id)/appRoleAssignments" -Method GET -Graph
        $currentAppRoles = $currentAssignments.value

        # Get all available Graph app roles
        $graphAppRoles = $graphSP.appRoles

        # Process each requested scope
        foreach ($scope in $Scopes) {
            Write-Verbose "Processing scope: $scope"

            # Find the app role for this scope
            $appRole = $graphAppRoles | Where-Object { $_.value -eq $scope }

            if (-not $appRole) {
                Write-Warning "Application permission '$scope' not found in Microsoft Graph. Skipping."
            }

            # Check if permission already exists
            $existingPermission = $currentAppRoles | Where-Object { $_.appRoleId -eq $appRole.id -and $_.resourceId -eq $graphSP.id }

            if ($existingPermission) {
                Write-Verbose "Permission '$scope' already exists"
            }

            Write-Host "➕ Adding permission '$scope'..." -ForegroundColor Yellow
            # Add the permission
            $permissionBody = @{
                principalId = $appSP.id
                resourceId  = $graphSP.id
                appRoleId   = $appRole.id
            } | ConvertTo-Json

            Write-Verbose "Adding permission: $scope"
            Invoke-MtAzureRequest -RelativeUri "servicePrincipals/$($appSP.id)/appRoleAssignments" -Method POST -Payload $permissionBody -Graph | Out-Null
            Write-Verbose "Successfully added permission: $scope"
        }
    }
}