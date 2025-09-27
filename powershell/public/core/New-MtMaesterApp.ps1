<#
.SYNOPSIS
    Creates a new Maester application in Entra ID with required permissions.

.DESCRIPTION
    Creates a new application registration in Entra ID specifically configured for running
    Maester tests in a DevOps pipeline. The application will be granted the necessary Graph API
    permissions based on the specified parameters and tagged for easy identification.

.PARAMETER Name
    The display name for the application. If not specified, defaults to 'Maester DevOps Account'.

.PARAMETER SendMail
    If specified, includes the Mail.Send permission scope.

.PARAMETER SendTeamsMessage
    If specified, includes the ChannelMessage.Send permission scope.

.PARAMETER Privileged
    If specified, includes privileged permission scopes for read-write operations.

.PARAMETER Scopes
    Additional custom permission scopes to include beyond the default Maester scopes.

.EXAMPLE
    New-MtMaesterApp

    Creates a new Maester app with default permissions and name 'Maester DevOps Account'.

.EXAMPLE
    New-MtMaesterApp -Name "My Maester Pipeline App" -SendMail

    Creates a new Maester app with mail sending capabilities.

.EXAMPLE
    New-MtMaesterApp -Privileged -Scopes @("User.Read.All", "Group.Read.All")

    Creates a new Maester app with privileged scopes and additional custom scopes.

.LINK
    https://maester.dev/docs/commands/New-MtMaesterApp
#>
function New-MtMaesterApp {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The display name for the application
        [Parameter(Mandatory = $false)]
        [string] $Name = "Maester DevOps Account",

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

    # if (-not (Test-MtConnection Graph)) {
    #     throw "Please connect to Microsoft Graph first using Connect-MgGraph or Connect-Maester"
    # }

    try {
        Write-Host "Creating new Maester application: $Name" -ForegroundColor Green

        # Create the application
        $appBody = @{
            displayName = $Name
            description = "Application created by Maester for running security assessments in DevOps pipelines"
            tags = @("maester")
            signInAudience = "AzureADMyOrg"
            web = @{
                redirectUris = @()
            }
        } | ConvertTo-Json -Depth 3

        if ($PSCmdlet.ShouldProcess($Name, "Create Maester application")) {
            Write-Verbose "Creating application with body: $appBody"
            $response = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications" -Method POST -Payload $appBody

            if ($response.StatusCode -ne 201) {
                throw "Failed to create application. Status: $($response.StatusCode), Content: $($response.Content)"
            }

            $app = $response.Content | ConvertFrom-Json
            Write-Host "✅ Application created successfully" -ForegroundColor Green
            Write-Host "   Application ID: $($app.appId)" -ForegroundColor Cyan
            Write-Host "   Object ID: $($app.id)" -ForegroundColor Cyan

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

            Write-Host "Configuring permissions..." -ForegroundColor Yellow
            Write-Verbose "Required scopes: $($requiredScopes -join ', ')"

            # Create a service principal for the app
            $spBody = @{
                appId = $app.appId
                tags = @("maester")
            } | ConvertTo-Json

            Write-Host "Creating service principal..." -ForegroundColor Yellow
            $spResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Method POST -Payload $spBody

            if ($spResponse.StatusCode -eq 201) {
                $servicePrincipal = $spResponse.Content | ConvertFrom-Json
                Write-Host "✅ Service principal created successfully" -ForegroundColor Green
                Write-Host "   Service Principal ID: $($servicePrincipal.id)" -ForegroundColor Cyan
            } else {
                Write-Warning "Failed to create service principal. You may need to create it manually."
            }

            # Set the permissions
            Set-MaesterAppPermissions -ApplicationId $app.appId -Scopes $requiredScopes

            # Set the logo
            Write-Host "Setting Maester logo..." -ForegroundColor Yellow
            Set-MaesterAppLogo -AppId $app.id


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
            Write-Host "🎉 Maester application created successfully!" -ForegroundColor Green
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Create a client secret or certificate for authentication" -ForegroundColor White
            Write-Host "2. Grant admin consent for the requested permissions" -ForegroundColor White
            Write-Host "3. Use the Application ID in your DevOps pipeline configuration" -ForegroundColor White

            return $result
        }
    }
    catch {
        Write-Error "Failed to create Maester application: $($_.Exception.Message)"
        throw
    }
}