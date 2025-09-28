<#
.SYNOPSIS
    Retrieves Maester applications from Azure AD/Entra ID.

.DESCRIPTION
    Retrieves all applications in Azure AD/Entra ID that have been tagged as Maester applications.
    This includes applications created by New-MtMaesterApp or manually tagged with 'maester'.

.PARAMETER AppId
    If specified, retrieves only the Maester application with the specified Application (Client) ID.

.PARAMETER Name
    If specified, retrieves only Maester applications with display names containing the specified text.

.EXAMPLE
    Get-MtMaesterApp

    Retrieves all Maester applications in the tenant.

.EXAMPLE
    Get-MtMaesterApp -AppId "12345678-1234-1234-1234-123456789012"

    Retrieves the specific Maester application with the given Application ID.

.EXAMPLE
    Get-MtMaesterApp -Name "DevOps"

    Retrieves all Maester applications that start with "DevOps" in their display name.

.LINK
    https://maester.dev/docs/commands/Get-MtMaesterApp
#>
function Get-MtMaesterApp {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [CmdletBinding()]
    param(
        # The ID of the Maester app to update
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [Alias('ObjectId')]
        [string] $Id,

        # The Application (Client) ID of the Maester app to update
        [Parameter(Mandatory = $true, ParameterSetName = 'ByApplicationId')]
        [Alias('ClientId')]
        [string] $AppId,

        # Filter by application display name (starts with)
        # The Application (Client) ID of the Maester app to update
        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [string] $Name
    )

    if (-not (Test-MtAzContext)) {
        return
    }

    Write-Verbose "Searching for Maester applications..."

    $select = "id,appId,displayName,description,tags,createdDateTime,signInAudience"

    if ($Id) {
        # If Id is specified, get the application directly
        Write-Verbose "Getting application with Object ID: $Id"
        $app = Invoke-MtAzureRequest -RelativeUri "applications/$Id" -Method GET -Graph -Select $select
        if ($null -eq $app.id) {
            Write-Warning "No application found with ID '$Id'."
            return
        }
        return Get-MaesterAppInfo -App $app
    } else {
        # Build the filter
        $filters = @()

        # Add AppId filter if specified
        if ($AppId) {
            $filters += "appId eq '$AppId'"
        } else {
            # Filter by the maester tag
            $filters += "tags/any(t:t eq 'maester')"
        }

        # Add Name filter if specified
        if ($Name) {
            $filters += "startswith(displayName, '$Name')"
        }

        $filter = $filters -join ' and '

        Write-Verbose "Query URI: $path"
        $result = Invoke-MtAzureRequest -RelativeUri "applications" -Method GET -Graph -Filter $filter -Select $select

        $apps = $result.value

        if ($apps.Count -eq 0) {
            if ($AppId) {
                Write-Warning "No Maester application found with App ID '$AppId'."
            } elseif ($Name) {
                Write-Warning "No Maester applications found with name containing '$Name'."
            } else {
                Write-Warning "No Maester applications found in this tenant."
                Write-Host "Use New-MtMaesterApp to create a new Maester application." -ForegroundColor Yellow
            }
            return
        }

        # Get service principal information for each app
        foreach ($app in $apps) {
            Get-MaesterAppInfo -App $app
        }
        Write-Verbose "Found $($apps.Count) Maester application(s)"
    }
}