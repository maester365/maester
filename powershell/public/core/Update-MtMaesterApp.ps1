<#
.SYNOPSIS
    Updates an existing Maester application with the latest required permissions.

.DESCRIPTION
    Updates an existing Maester application in Azure AD/Entra ID with the current set of required
    Graph API permissions. This is useful when new permissions are added to Maester and existing
    applications need to be updated to include them.

.PARAMETER ApplicationId
    The Application (Client) ID of the existing Maester application to update.

.PARAMETER SendMail
    If specified, includes the Mail.Send permission scope.

.PARAMETER SendTeamsMessage
    If specified, includes the ChannelMessage.Send permission scope.

.PARAMETER Privileged
    If specified, includes privileged permission scopes for read-write operations.

.PARAMETER Scopes
    Additional custom permission scopes to include beyond the default Maester scopes.

.EXAMPLE
    Update-MtMaesterApp -ApplicationId "12345678-1234-1234-1234-123456789012"

    Updates the specified Maester app with the current default permissions.

.EXAMPLE
    Update-MtMaesterApp -ApplicationId "12345678-1234-1234-1234-123456789012" -SendMail -Privileged

    Updates the specified Maester app with mail sending and privileged capabilities.

.EXAMPLE
    Update-MtMaesterApp -ApplicationId "12345678-1234-1234-1234-123456789012" -Scopes @("User.Read.All")

    Updates the specified Maester app with additional custom scopes.

.LINK
    https://maester.dev/docs/commands/Update-MtMaesterApp
#>
function Update-MtMaesterApp {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The Application (Client) ID of the Maester app to update
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('AppId', 'ClientId')]
        [string] $ApplicationId,

        # Include Mail.Send permission scope
        [Parameter(Mandatory = $false)]
        [switch] $SendMail,

        # Include ChannelMessage.Send permission scope
        [Parameter(Mandatory = $false)]
        [switch] $SendTeamsMessage,

        # Include privileged permission scopes
        [Parameter(Mandatory = $false)]
        [switch] $Privileged,

        # Additional custom permission scopes
        [Parameter(Mandatory = $false)]
        [string[]] $Scopes = @()
    )

    begin {
        if (-not (Test-MtConnection Graph)) {
            throw "Please connect to Microsoft Graph first using Connect-MgGraph or Connect-Maester"
        }
    }

    process {
        try {
            Write-Host "Updating Maester application: $ApplicationId" -ForegroundColor Green

            # Find the application by AppId
            $appFilter = "appId eq '$ApplicationId'"
            $appResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=$appFilter" -Method GET

            if ($appResponse.StatusCode -ne 200) {
                throw "Failed to query applications. Status: $($appResponse.StatusCode)"
            }

            $apps = ($appResponse.Content | ConvertFrom-Json).value

            if ($apps.Count -eq 0) {
                Write-Error "Application with ID '$ApplicationId' not found. Use Get-MtMaesterApp to find existing Maester applications."
                return
            }

            $app = $apps[0]
            Write-Host "✅ Found application: $($app.displayName)" -ForegroundColor Green

            # Verify this is a Maester app
            if ($app.tags -notcontains "maester") {
                Write-Warning "Application '$($app.displayName)' does not have the 'maester' tag. This may not be a Maester application."
                $confirmation = Read-Host "Do you want to continue? (y/N)"
                if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                    Write-Host "Update cancelled." -ForegroundColor Yellow
                    return
                }
            }

            if ($PSCmdlet.ShouldProcess($app.displayName, "Update Maester application permissions")) {
                # Get the required scopes
                $scopeParams = @{}
                if ($SendMail) { $scopeParams['SendMail'] = $true }
                if ($SendTeamsMessage) { $scopeParams['SendTeamsMessage'] = $true }
                if ($Privileged) { $scopeParams['Privileged'] = $true }

                $requiredScopes = Get-MtGraphScope @scopeParams

                # Add any additional custom scopes
                if ($Scopes) {
                    $requiredScopes += $Scopes
                    $requiredScopes = $requiredScopes | Sort-Object -Unique
                }

                Write-Host "Updating permissions..." -ForegroundColor Yellow
                Write-Verbose "Required scopes: $($requiredScopes -join ', ')"

                # Set the permissions
                Set-MaesterAppPermissions -ApplicationId $app.appId -Scopes $requiredScopes

                # Update the logo (in case it has changed)
                Write-Host "Updating Maester logo..." -ForegroundColor Yellow
                Set-MaesterAppLogo -AppId $app.id

                # Update the application tags and description
                $updateBody = @{
                    tags = @("maester")
                    description = "Application created by Maester for running security assessments in DevOps pipelines"
                } | ConvertTo-Json

                Write-Host "Updating application metadata..." -ForegroundColor Yellow
                $updateResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" -Method POST -Payload $updateBody

                if ($updateResponse.StatusCode -ne 204) {
                    Write-Warning "Failed to update application metadata. Status: $($updateResponse.StatusCode)"
                }

                # Get the service principal
                $spFilter = "appId eq '$ApplicationId'"
                $spResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$spFilter" -Method GET
                $servicePrincipal = $null

                if ($spResponse.StatusCode -eq 200) {
                    $servicePrincipals = ($spResponse.Content | ConvertFrom-Json).value
                    if ($servicePrincipals.Count -gt 0) {
                        $servicePrincipal = $servicePrincipals[0]
                    }
                }

                # Output the result
                $result = [PSCustomObject]@{
                    DisplayName = $app.displayName
                    ApplicationId = $app.appId
                    ObjectId = $app.id
                    ServicePrincipalId = if ($servicePrincipal) { $servicePrincipal.id } else { $null }
                    RequiredScopes = $requiredScopes
                    Tags = $app.tags
                }

                Write-Host ""
                Write-Host "🎉 Maester application updated successfully!" -ForegroundColor Green
                Write-Host "Note: You may need to grant admin consent for any new permissions." -ForegroundColor Yellow

                return $result
            }
        }
        catch {
            Write-Error "Failed to update Maester application '$ApplicationId': $($_.Exception.Message)"
            throw
        }
    }
}