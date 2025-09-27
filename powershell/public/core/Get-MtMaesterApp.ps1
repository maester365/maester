<#
.SYNOPSIS
    Retrieves Maester applications from Azure AD/Entra ID.

.DESCRIPTION
    Retrieves all applications in Azure AD/Entra ID that have been tagged as Maester applications.
    This includes applications created by New-MtMaesterApp or manually tagged with 'maester'.

.PARAMETER ApplicationId
    If specified, retrieves only the Maester application with the specified Application (Client) ID.

.PARAMETER Name
    If specified, retrieves only Maester applications with display names containing the specified text.

.EXAMPLE
    Get-MtMaesterApp

    Retrieves all Maester applications in the tenant.

.EXAMPLE
    Get-MtMaesterApp -ApplicationId "12345678-1234-1234-1234-123456789012"

    Retrieves the specific Maester application with the given Application ID.

.EXAMPLE
    Get-MtMaesterApp -Name "DevOps"

    Retrieves all Maester applications with "DevOps" in their display name.

.LINK
    https://maester.dev/docs/commands/Get-MtMaesterApp
#>
function Get-MtMaesterApp {
    [CmdletBinding()]
    param(
        # Filter by specific Application (Client) ID
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('AppId', 'ClientId')]
        [string] $ApplicationId,

        # Filter by application display name (contains)
        [Parameter(Mandatory = $false)]
        [string] $Name
    )

    begin {
        if (-not (Test-MtConnection Graph)) {
            throw "Please connect to Microsoft Graph first using Connect-MgGraph or Connect-Maester"
        }
    }

    process {
        try {
            Write-Verbose "Searching for Maester applications..."

            # Build the filter
            $filters = @()

            # Always filter by the maester tag
            $filters += "tags/any(t:t eq 'maester')"

            # Add ApplicationId filter if specified
            if ($ApplicationId) {
                $filters += "appId eq '$ApplicationId'"
            }

            # Add Name filter if specified
            if ($Name) {
                $filters += "startswith(displayName, '$Name')"
            }

            $filter = $filters -join ' and '
            $selectFields = @('id', 'appId', 'displayName', 'description', 'tags', 'createdDateTime', 'publisherDomain', 'signInAudience')

            Write-Verbose "Query filter: $filter"
            $apps = Invoke-MtGraphRequest -RelativeUri "applications" -Filter $filter -Select $selectFields -DisableCache

            # Ensure we always have an array to work with
            if (-not $apps) {
                $apps = @()
            } elseif ($apps -is [PSCustomObject]) {
                $apps = @($apps)
            }

            if ($apps.Count -eq 0) {
                if ($ApplicationId) {
                    Write-Warning "No Maester application found with Application ID '$ApplicationId'."
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
                Write-Verbose "Getting service principal for app: $($app.appId)"

                try {
                    $servicePrincipals = Invoke-MtGraphRequest -RelativeUri "servicePrincipals" -Filter "appId eq '$($app.appId)'" -Select @('id', 'servicePrincipalType') -DisableCache

                    $servicePrincipal = $null
                    if ($servicePrincipals) {
                        if ($servicePrincipals -is [Array] -and $servicePrincipals.Count -gt 0) {
                            $servicePrincipal = $servicePrincipals[0]
                        } elseif ($servicePrincipals -is [PSCustomObject]) {
                            $servicePrincipal = $servicePrincipals
                        }
                    }

                    # Create the output object
                    $appInfo = [PSCustomObject]@{
                        DisplayName = $app.displayName
                        ApplicationId = $app.appId
                        ObjectId = $app.id
                        ServicePrincipalId = if ($servicePrincipal) { $servicePrincipal.id } else { $null }
                        Description = $app.description
                        CreatedDateTime = $app.createdDateTime
                        PublisherDomain = $app.publisherDomain
                        SignInAudience = $app.signInAudience
                        Tags = $app.tags
                        HasServicePrincipal = $null -ne $servicePrincipal
                    }

                    # Add type information for formatting
                    $appInfo.PSTypeNames.Insert(0, 'Maester.Application')

                    Write-Output $appInfo
                }
                catch {
                    Write-Warning "Failed to get service principal information for app '$($app.displayName)': $($_.Exception.Message)"

                    # Still output the app information without service principal details
                    $appInfo = [PSCustomObject]@{
                        DisplayName = $app.displayName
                        ApplicationId = $app.appId
                        ObjectId = $app.id
                        ServicePrincipalId = $null
                        Description = $app.description
                        CreatedDateTime = $app.createdDateTime
                        PublisherDomain = $app.publisherDomain
                        SignInAudience = $app.signInAudience
                        Tags = $app.tags
                        HasServicePrincipal = $false
                    }

                    $appInfo.PSTypeNames.Insert(0, 'Maester.Application')
                    Write-Output $appInfo
                }
            }

            Write-Verbose "Found $($apps.Count) Maester application(s)"
        }
        catch {
            Write-Error "Failed to retrieve Maester applications: $($_.Exception.Message)"
            throw
        }
    }
}