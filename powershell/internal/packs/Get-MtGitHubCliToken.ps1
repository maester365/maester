function Get-MtGitHubCliToken {
    <#
    .SYNOPSIS
    Asks the GitHub CLI for the github.com token it is signed in with, or returns $null.

    .DESCRIPTION
    Runs `gh auth token --hostname github.com` when the gh CLI is installed. The token is returned to the
    caller and kept nowhere. Returns $null when gh is not installed, is not signed in, or fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $gh = Get-Command -Name 'gh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gh) { return $null }
    try {
        $output = & $gh.Source auth token --hostname github.com 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        $token = ([string]($output | Select-Object -First 1)).Trim()
        if ($token) { $token } else { $null }
    } catch {
        Write-Debug "gh auth token failed: $_"
        $null
    }
}
