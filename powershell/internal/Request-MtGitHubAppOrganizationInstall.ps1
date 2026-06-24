function Request-MtGitHubAppOrganizationInstall {
    <#
    .SYNOPSIS
    Guides an interactive user through installing or approving the Maester GitHub App for an organization.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Consistent with other Connect-* interactive flows')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $InstallUrl,

        [Parameter(Mandatory = $false)]
        [string] $Reason,

        [Parameter(Mandatory = $false)]
        [string] $TokenDocsUrl = 'https://maester.dev/docs/commands/Connect-MtGitHub'
    )

    if (-not (Get-MtUserInteractive)) {
        return $false
    }

    Write-Host ''
    Write-Host "The Maester GitHub App must be installed or approved for organization '$Organization' before Maester can read organization settings." -ForegroundColor Yellow
    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        Write-Host "GitHub API: $Reason" -ForegroundColor DarkGray
    }
    Write-Host "If you continue, Maester will open the GitHub App install page: $InstallUrl" -ForegroundColor Yellow
    Write-Host "GitHub will ask you to select '$Organization' and install, request, or approve the app. Maester will retry the connection after you finish." -ForegroundColor Yellow

    $response = Read-Host "Open the GitHub App install page now? (Y/N)"
    if ($response -notmatch '^(?i:y|yes)$') {
        Write-Host ''
        Write-Host 'No problem. You can use a GitHub token instead of the Maester GitHub App.' -ForegroundColor Yellow
        Write-Host 'Create a classic PAT with admin:org, or a fine-grained token with Organization Members: read and Organization Administration: read.' -ForegroundColor Yellow
        Write-Host 'Then reconnect with one of these options:' -ForegroundColor Yellow
        Write-Host '  $token = Read-Host "GitHub token" -AsSecureString' -ForegroundColor Cyan
        Write-Host "  Connect-MtGitHub -Organization '$Organization' -Token `$token" -ForegroundColor Cyan
        Write-Host "  `$env:MAESTER_GITHUB_TOKEN = '<token>'; Connect-MtGitHub -Organization '$Organization'" -ForegroundColor Cyan
        Write-Host "See the Maester docs for token-based GitHub auth: $TokenDocsUrl" -ForegroundColor Yellow
        return $false
    }

    $opened = Open-MtBrowserUrl -Uri $InstallUrl
    if ($opened) {
        Write-Host "Opened the Maester GitHub App install page in your browser." -ForegroundColor Yellow
    } else {
        Write-Host "Open the Maester GitHub App install page: $InstallUrl" -ForegroundColor Yellow
    }
    Write-Host "Select '$Organization', then install or request/approve the app for the organization." -ForegroundColor Yellow
    $null = Read-Host "Press Enter after the Maester GitHub App is installed or approved for '$Organization' to retry"
    return $true
}
