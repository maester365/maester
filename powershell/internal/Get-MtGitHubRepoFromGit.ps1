function Get-MtGitHubRepoFromGit {
    <#
    .SYNOPSIS
    Detects the current GitHub repository from the local git remote (origin).

    .DESCRIPTION
    Used by Add-MtMaesterAppFederatedCredential and New-MtMaesterApp to remove
    the need for the user to specify -GitHubOrganization and -GitHubRepository
    when running the command from inside a git working tree whose `origin` remote
    points at GitHub.

    Supports both HTTPS and SSH remote URL formats:
        https://github.com/owner/repo.git
        https://github.com/owner/repo
        git@github.com:owner/repo.git

    Returns $null when:
        * git is not installed / not on PATH
        * the current directory is not inside a git working tree
        * the origin remote is not a GitHub URL
        * the URL cannot be parsed

    .OUTPUTS
    [pscustomobject] with Organization, Repository, RemoteUrl properties, or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Optional override for the git remote name. Defaults to 'origin'.
        [string] $RemoteName = 'origin'
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Verbose "git is not available on PATH; cannot auto-detect GitHub repo."
        return $null
    }

    try {
        $remoteUrl = (& git remote get-url $RemoteName 2>$null) | Select-Object -First 1
    } catch {
        Write-Verbose "Failed to read git remote '$RemoteName': $($_.Exception.Message)"
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
        Write-Verbose "git remote '$RemoteName' is not configured."
        return $null
    }

    # Match HTTPS, SSH, and scp-style GitHub URLs.
    $pattern = '^(?:https?://[^/]*github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/([^/]+?)(?:\.git)?/?\s*$'
    if ($remoteUrl -notmatch $pattern) {
        Write-Verbose "Remote URL '$remoteUrl' is not a recognised GitHub URL."
        return $null
    }

    return [pscustomobject]@{
        Organization = $Matches[1]
        Repository   = $Matches[2]
        RemoteUrl    = $remoteUrl.Trim()
    }
}
