function Get-MtGitHubRepoFromString {
    <#
    .SYNOPSIS
    Internal: Parses a GitHub repository identifier from a URL or 'owner/repo' shorthand.

    .DESCRIPTION
    Used by Install-MtCustomTests so users can point at a source repository using either
    the 'owner/repo' shorthand or a full GitHub URL (HTTPS, HTTPS with a .git suffix,
    SSH, or a URL with a trailing path such as /tree/main).

    Host is anchored to github.com (optional 'www.') so lookalikes such as
    'evilgithub.com' do not match. Owner/repo characters are restricted to the set
    GitHub allows, since the parsed values are later interpolated into download URLs.

    Returns $null when the input cannot be parsed as a GitHub repository.

    .OUTPUTS
    [pscustomobject] with Organization and Repository properties, or $null.

    .EXAMPLE
    Get-MtGitHubRepoFromString -Repository 'Mynster9361/Least_Privileged_MSGraph'

    .EXAMPLE
    Get-MtGitHubRepoFromString -Repository 'https://github.com/Mynster9361/Least_Privileged_MSGraph'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Repository
    )

    $trimmed = $Repository.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $null
    }

    $pattern = '^(?:https?://(?:www\.)?github\.com/|git@github\.com:|ssh://git@github\.com/)?([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?(?:[/?#].*)?$'
    if ($trimmed -notmatch $pattern) {
        return $null
    }

    return [pscustomobject]@{
        Organization = $Matches[1]
        Repository   = $Matches[2]
    }
}
