<#
.SYNOPSIS
    Creates a new Maester application in Entra ID with required permissions.

.DESCRIPTION
    Creates a new application registration in Entra ID specifically configured for running
    Maester tests in a DevOps pipeline. The application will be granted the necessary Graph API
    permissions based on the specified parameters and tagged for easy identification.

    The user running this command must have a permissions to create applications and consent to Graph Permissions.
    This requires a minimum of being a Privileged Role Administrator (and Cloud Application Administrator if needed) or Global Administrator.

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param(
        # The display name for the application
        [string] $Name,

        # Include Mail.Send permission scope
        [switch] $SendMail,

        # Include ChannelMessage.Send permission scope
        [switch] $SendTeamsMessage,

        # Include privileged permission scopes
        [switch] $Privileged,

        # Additional custom permission scopes
        [string[]] $Scopes = @(),

        # If specified adds federated credential for GitHub Actions
        # Your GitHub organization name or GitHub username. E.g. jasonf
        [string] $GitHubOrganization,

        # Your GitHub repository name where the GitHub Actions workflow is located. E.g. maester-tests
        [string] $GitHubRepository
    )

    # We use the Azure module to create the app registration since it has pre-consented permissions to create apps
    # Maester is meant for read-only access, so we don't want users to consent to Application.ReadWrite.All or similar.
    # Instead, we create the app using the Az module context and then assign only the minimum required permissions.
    # This also avoids needing admin consent during Connect-MgGraph.
    if (-not (Test-MtAzContext)) {
        return
    }

    if ($GitHubOrganization -or $GitHubRepository) {
        if (-not $GitHubOrganization -or -not $GitHubRepository) {
            Write-Error "Both GitHubOrganization and GitHubRepository must be specified to add a federated credential."
            return
        }
    }

    if (-not $Name) {
        if($GitHubOrganization -and $GitHubRepository) {
            $Name = "Maester DevOps Account - $GitHubOrganization/$GitHubRepository"
        } else {
            $Name = "Maester DevOps Account"
        }
    }

    $existingApps = Get-MtMaesterApp -WarningAction SilentlyContinue
    $appCount = ($existingApps | Measure-Object).Count
    if ($appCount -gt 0) {
        Write-Warning "We found $appCount Maester application(s) in this tenant."
        $existingApps

        $confirmation = Read-Host "Create a new Maester application anyway? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "Update cancelled." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "Creating new Maester application: $Name" -ForegroundColor Green

    # Create the application
    $appBody = @{
        displayName = $Name
        description = "Application created by Maester for running security assessments in DevOps pipelines"
        tags        = @('maester')
    } | ConvertTo-Json -Depth 3

    Write-Verbose "Creating application with body: $appBody"
    $app = Invoke-MtAzureRequest -RelativeUri 'applications' -Method POST -Payload $appBody -Graph

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

    # Create a service principal for the app
    $spBody = @{
        appId = $app.appId
        tags  = @("maester")
    } | ConvertTo-Json

    Write-Host "Creating service principal..." -ForegroundColor Yellow
    $servicePrincipal = Invoke-MtAzureRequest -RelativeUri "servicePrincipals" -Method POST -Payload $spBody -Graph
    Write-Host "✅ Service principal created successfully" -ForegroundColor Green
    Write-Host "   Service Principal ID: $($servicePrincipal.id)" -ForegroundColor Cyan

    # Set the permissions
    Write-Host "Configuring permissions..." -ForegroundColor Yellow
    Write-Verbose "Required scopes: $($requiredScopes -join ', ')"

    Set-MaesterAppPermission -AppId $app.appId -Scopes $requiredScopes

    $result = Get-MtMaesterApp -Id $app.id

    Write-Host ""
    Write-Host "🎉 Maester application created successfully!" -ForegroundColor Green

    if ($GitHubOrganization) {
        Add-MtMaesterAppFederatedCredential -AppId $app.appId -GitHubOrganization $GitHubOrganization -GitHubRepository $GitHubRepository
    } else {
        Write-Output $result
    }
}