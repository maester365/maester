[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
param ()

# Check if environment variables indicate running in a CI/CD environment.
$CiCdEnvironment = @(
    # GitHub Actions
    $env:GITHUB_ACTIONS -eq 'true',
    # GitLab CI
    $env:GITLAB_CI -eq 'true',
    # Azure DevOps
    $env:TF_BUILD -eq 'true',
    # Bitbucket Pipelines
    $null -ne $env:BITBUCKET_BUILD_NUMBER,
    # Jenkins
    $null -ne $env:JENKINS_URL,
    # CircleCI
    $env:CIRCLECI -eq 'true',
    # Travis CI
    $env:TRAVIS -eq 'true',
    # TeamCity
    $null -ne $env:TEAMCITY_VERSION
)

# Check if environment variables indicate running within a container environment.
$ContainerEnvironment = @(
    # Check for Docker
    (Test-Path -Path '/.dockerenv'),
    # Check for common container environment variables
    $env:KUBERNETES_SERVICE_HOST -ne $null,
    # Check for Windows container
    $env:CONTAINER -eq 'true'
)

$NonInteractive = if (
    (-not [Environment]::UserInteractive) -or
    ([Environment]::GetCommandLineArgs() -match 'NonInteractive') -or
    $CiCdEnvironment -or
    $ContainerEnvironment
) {
    $true
}

if ($NonInteractive) {
    Write-Verbose "Maester is running in non-interactive mode. Skipping welcome message."
    return
}

try {
    . "$PSScriptRoot/internal/Show-MtLogo.ps1" -ErrorAction Stop
    Show-MtLogo
} catch {
    Write-Host "Importing Maester v$((Import-PowerShellDataFile -Path "$PSScriptRoot/../Maester.psd1" -ErrorAction SilentlyContinue).ModuleVersion)." -ForegroundColor Green
}

Write-Host "    To get started, install Maester tests and connect before running Maester:`n" -ForegroundColor Yellow
Write-Host "`tmd 'maester-tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tcd 'maester-tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInstall-MaesterTests         " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tConnect-Maester -Service All " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInvoke-Maester               " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`n    See https://maester.dev for more info.🔥`n" -ForegroundColor Yellow
