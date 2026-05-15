function Write-MtGitHubSecretsManualInstruction {
    <#
    .SYNOPSIS
    Prints the manual GitHub Actions secrets setup instructions used as a fallback by
    Add-MtMaesterAppFederatedCredential when -SetGitHubSecrets is not used or when the
    GitHub CLI (`gh`) is unavailable / unauthenticated / fails.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    param(
        [Parameter(Mandatory = $true)] [string] $GitHubOrganization,
        [Parameter(Mandatory = $true)] [string] $GitHubRepository,
        [Parameter(Mandatory = $true)] [string] $ClientId,
        [Parameter(Mandatory = $true)] [string] $TenantId
    )

    $githubSecretsUrl = "https://github.com/$GitHubOrganization/$GitHubRepository/settings/secrets/actions"

    Write-Host "GitHub Actions Configuration:" -ForegroundColor Yellow
    Write-Host "Add these secrets to your GitHub repository ($GitHubOrganization/$GitHubRepository):" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Browse to $githubSecretsUrl" -ForegroundColor Cyan
    Write-Host "2. Click on 'New repository secret'" -ForegroundColor Cyan
    Write-Host "3. Create the following secrets:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Name: AZURE_CLIENT_ID" -ForegroundColor Cyan
    Write-Host "    Value: $ClientId" -ForegroundColor Cyan
    Write-Host "   Name: AZURE_TENANT_ID" -ForegroundColor Cyan
    Write-Host "    Value: $TenantId" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tip: re-run with -SetGitHubSecrets to push these via the GitHub CLI automatically." -ForegroundColor DarkGray
    Write-Host "See https://maester.dev/docs/monitoring/github#add-entra-tenant-info-to-github-repos for details." -ForegroundColor Yellow
    Write-Host ""
}
