function Set-MtGitHubActionsSecret {
    <#
    .SYNOPSIS
    Sets AZURE_CLIENT_ID and AZURE_TENANT_ID as GitHub Actions repository secrets via the GitHub CLI.

    .DESCRIPTION
    Used by Add-MtMaesterAppFederatedCredential when -SetGitHubSecrets is specified.
    Returns $true when both secrets were set successfully, $false otherwise (caller
    should fall back to printing manual setup instructions).

    Requires the GitHub CLI (`gh`) to be installed and authenticated. Will validate
    both before attempting any state-changing call.

    .OUTPUTS
    [bool] - $true on success, $false if gh is missing/unauthenticated or any
    `gh secret set` call fails.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'User opted in via -SetGitHubSecrets switch on the calling cmdlet')]
    param(
        # Target repository in 'owner/repo' format.
        [Parameter(Mandatory = $true)]
        [string] $GitHubRepository,

        # Application (Client) ID to store as AZURE_CLIENT_ID.
        [Parameter(Mandatory = $true)]
        [string] $ClientId,

        # Entra Tenant ID to store as AZURE_TENANT_ID.
        [Parameter(Mandatory = $true)]
        [string] $TenantId
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning "GitHub CLI ('gh') is not installed or not on PATH. Falling back to manual instructions."
        Write-Host "Install gh from https://cli.github.com/ to enable -SetGitHubSecrets." -ForegroundColor DarkGray
        return $false
    }

    # Validate gh auth - 'gh auth status' exits 0 when authenticated.
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "GitHub CLI is not authenticated. Run 'gh auth login' first. Falling back to manual instructions."
        return $false
    }

    Write-Host "Setting GitHub Actions secrets on $GitHubRepository via gh CLI..." -ForegroundColor Yellow

    $secrets = [ordered]@{
        AZURE_CLIENT_ID = $ClientId
        AZURE_TENANT_ID = $TenantId
    }

    foreach ($name in $secrets.Keys) {
        $value = $secrets[$name]
        $output = & gh secret set $name --repo $GitHubRepository --body $value 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to set $name on $GitHubRepository : $output"
            return $false
        }
        Write-Host "  ✓ $name set" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ AZURE_CLIENT_ID and AZURE_TENANT_ID configured on $GitHubRepository." -ForegroundColor Green
    Write-Host ""
    return $true
}
