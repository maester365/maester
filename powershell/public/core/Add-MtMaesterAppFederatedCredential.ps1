function Add-MtMaesterAppFederatedCredential {
    <#
    .SYNOPSIS
    Adds a federated credential to a Maester application for GitHub Actions authentication.

    .DESCRIPTION
    Adds a federated credential (workload identity) to a Maester application to enable
    authentication from GitHub Actions workflows without using client secrets.
    The credential allows the specified GitHub repository and branch to authenticate
    as the application.

    .PARAMETER Id
    The Object ID of the Maester application to add the federated credential to.

    .PARAMETER AppId
    The Application (Client) ID of the Maester application to add the federated credential to.

    .PARAMETER GitHubRepository
    The GitHub repository name (without the organization). E.g. maester-tests.
    If omitted (together with -GitHubOrganization) and the current working directory is
    inside a git repository whose 'origin' remote points at GitHub, the repository is
    auto-detected from `git remote get-url origin`.

    .PARAMETER GitHubBranch
    The GitHub branch that can use this credential. Defaults to 'main'.

    .PARAMETER Name
    The name for the federated credential. Defaults to 'maester-devops-<org>-<repo>'.

    .PARAMETER SetGitHubSecrets
    If specified, sets the AZURE_CLIENT_ID and AZURE_TENANT_ID secrets on the target
    GitHub repository using the GitHub CLI (`gh`). Requires `gh` to be installed and
    authenticated (`gh auth login`). When the secrets cannot be set automatically the
    cmdlet falls back to printing the manual setup instructions.

    .PARAMETER Force
    Skip the confirmation prompt if a similar credential already exists.

    .EXAMPLE
    Add-MtMaesterAppFederatedCredential -AppId "12345678-1234-1234-1234-123456789012" -GitHubOrganization "myorg" -GitHubRepository "myrepo"

    Adds a federated credential for the main branch of myorg/myrepo to the specified Maester app.

    .EXAMPLE
    Add-MtMaesterAppFederatedCredential -Id "87654321-4321-4321-4321-210987654321" -GitHubOrganization "myorg" -GitHubRepository "myrepo" -Name "maester-develop"

    Adds a federated credential for the develop branch with a custom name.

    .EXAMPLE
    Add-MtMaesterAppFederatedCredential -AppId "12345678-1234-1234-1234-123456789012" -SetGitHubSecrets

    Auto-detects the GitHub organization and repository from the current git remote, adds
    the federated credential, and pushes AZURE_CLIENT_ID / AZURE_TENANT_ID to the repo's
    Actions secrets via the GitHub CLI.

    .LINK
    https://maester.dev/docs/commands/Add-MtMaesterAppFederatedCredential
    #>
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

        # Your GitHub organization name or GitHub username. E.g. jasonf.
        # If omitted (together with -GitHubRepository) the value is auto-detected from
        # the local git remote ('origin') when the current directory is a git repo.
        [Parameter(Mandatory = $false)]
        [string] $GitHubOrganization,

        # Your GitHub repository name where the GitHub Actions workflow is located. E.g. maester-tests.
        # Auto-detected from the local git remote ('origin') when omitted.
        [Parameter(Mandatory = $false)]
        [string] $GitHubRepository,

        # The GitHub branch that can use this credential
        [Parameter(Mandatory = $false)]
        [string] $GitHubBranch = 'main',

        # The name for the federated credential
        [Parameter(Mandatory = $false)]
        [string] $Name,

        # If set, also pushes AZURE_CLIENT_ID and AZURE_TENANT_ID to the GitHub repo's
        # Actions secrets using the GitHub CLI (`gh`). Falls back to printing manual
        # instructions if `gh` is not installed or not authenticated.
        [Parameter(Mandatory = $false)]
        [switch] $SetGitHubSecrets
    )

    if (-not (Test-MtAzContext)) {
        return
    }

    # Auto-detect GitHub org/repo from the local git remote when caller didn't provide them.
    if (-not $GitHubOrganization -or -not $GitHubRepository) {
        $detected = Get-MtGitHubRepoFromGit
        if ($detected) {
            if (-not $GitHubOrganization) { $GitHubOrganization = $detected.Organization }
            if (-not $GitHubRepository)   { $GitHubRepository   = $detected.Repository }
            Write-Host "Auto-detected GitHub repository from git remote: $GitHubOrganization/$GitHubRepository" -ForegroundColor Cyan
        }
    }

    if (-not $GitHubOrganization -or -not $GitHubRepository) {
        Write-Error "GitHubOrganization and GitHubRepository are required. They can be auto-detected when the current directory is a git working tree whose 'origin' remote points at GitHub."
        return
    }

    try {
        if ($Id) {
            $params = @{ Id = $Id }
        } elseif ($AppId) {
            $params = @{ AppId = $AppId }
        }

        $app = Get-MtMaesterApp @params
        if (-not $app) {
            $errorId = if($Id) { $Id } else { $AppId }
            Write-Error "Maester application not found with the specified identifier: $errorId."
            return
        }

        Write-Host "Adding federated credential to Maester application" -ForegroundColor Green
        Write-Output $app

        if (-not $Name) { # Set default name if not provided
            $Name = "maester-devops-$($GitHubOrganization)-$($GitHubRepository)"
        }
        $githubIssuer = "https://token.actions.githubusercontent.com"

        # Check for existing federated credentials
        Write-Verbose "Checking for existing federated credentials..."
        $existingCredsResponse = Invoke-MtAzureRequest -RelativeUri "applications/$($app.id)/federatedIdentityCredentials" -Method GET -Graph

        $existingCreds = $existingCredsResponse.value

        # Check if a similar credential already exists
        $duplicateName = $existingCreds | Where-Object { $_.name -eq $Name }
        $duplicateSubject = $existingCreds | Where-Object {
            ($_.subject -eq "repo:$GitHubOrganization/$GitHubRepository`:ref:refs/heads/$GitHubBranch" -and $_.issuer -eq $githubIssuer)
        }

        if ($duplicateName -or $duplicateSubject) {
            if($duplicateSubject) {
                Write-Error "A federated credential for this repository already exists:"
                $duplicateCred += $duplicateSubject
            }
            elseif($duplicateName) {
                Write-Error "A federated credential with this name already exists:"
                $duplicateCred = $duplicateName
            }

            $duplicateCred | ForEach-Object {
                Write-Host "  Name: $($_.name)" -ForegroundColor Yellow
                Write-Host "  Subject: $($_.subject)" -ForegroundColor Yellow
                Write-Host ""
            }
            return
        }

        # Create the federated credential
        $federatedCredential = @{
            name        = $Name
            issuer      = $githubIssuer
            subject     = "repo:$GitHubOrganization/$GitHubRepository`:ref:refs/heads/$GitHubBranch"
            audiences   = @("api://AzureADTokenExchange")
            description = "Federated credential for GitHub Actions in $GitHubOrganization/$GitHubRepository ($GitHubBranch branch) - Created by Maester"
        } | ConvertTo-Json -Depth 3

        Write-Verbose "Creating federated credential with payload: $federatedCredential"

        $createdCredential = Invoke-MtAzureRequest -RelativeUri "applications/$($app.id)/federatedIdentityCredentials" -Method POST -Payload $federatedCredential -Graph

        if ($createdCredential.error) {
            throw "Failed to create federated credential. Error: $($createdCredential.error.message)"
        }

        $githubSecretsUrl = "https://github.com/$GitHubOrganization/$GitHubRepository/settings/secrets/actions"
        $tenantId = (Get-AzContext).Tenant.Id

        Write-Host ""
        Write-Host "🎉 Federated credential created successfully!" -ForegroundColor Green
        Write-Host ""

        $secretsConfigured = $false
        if ($SetGitHubSecrets) {
            $secretsConfigured = Set-MtGitHubActionsSecret -GitHubRepository "$GitHubOrganization/$GitHubRepository" -ClientId $app.AppId -TenantId $tenantId
        }

        if (-not $secretsConfigured) {
            Write-Host "GitHub Actions Configuration:" -ForegroundColor Yellow
            Write-Host "Add these secrets to your GitHub repository ($GitHubOrganization/$GitHubRepository):" -ForegroundColor White
            Write-Host ""
            Write-Host "1. Browse to $githubSecretsUrl" -ForegroundColor Cyan
            Write-Host "2. Click on 'New repository secret'" -ForegroundColor Cyan
            Write-Host "3. Create the following secrets:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "   Name: AZURE_CLIENT_ID" -ForegroundColor Cyan
            Write-Host "    Value: $($app.AppId)" -ForegroundColor Cyan
            Write-Host "   Name: AZURE_TENANT_ID" -ForegroundColor Cyan
            Write-Host "    Value: $tenantId" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Tip: re-run with -SetGitHubSecrets to push these via the GitHub CLI automatically." -ForegroundColor DarkGray
            Write-Host "See https://maester.dev/docs/monitoring/github#add-entra-tenant-info-to-github-repos for details." -ForegroundColor Yellow
            Write-Host ""
        }

        return $createdCredential

    } catch {
        Write-Error "Failed to add federated credential: $($_.Exception.Message)"
        throw
    }
}
