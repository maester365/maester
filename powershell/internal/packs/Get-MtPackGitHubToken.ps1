function Get-MtPackGitHubToken {
    <#
    .SYNOPSIS
    Reads the GitHub token one source holds for pack installs, or returns $null.

    .DESCRIPTION
    Invoke-MtPackGitHubRequest asks each source in turn, at the moment of a request, and keeps none of the
    answers:

    - Parameter: the -Token a person passed to Install-MtPack, Update-MtPack or Restore-MtPack.
    - Session: the sign-in Connect-MtGitHub holds for this session. It is used only when that connection is
      to https://api.github.com and has not expired, so a token for a GitHub Enterprise Cloud tenant with
      data residency (api.<name>.ghe.com) is never sent to github.com.
    - GitHubCli: `gh auth token`, when the gh CLI is installed and signed in (Get-MtGitHubCliToken).
    - GH_TOKEN and GITHUB_TOKEN: the environment variables, which pipelines set.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Parameter', 'Session', 'GitHubCli', 'GH_TOKEN', 'GITHUB_TOKEN')]
        [string] $Source,

        # The -Token parameter of the pack command, for the Parameter source.
        [Parameter()]
        [AllowNull()]
        [securestring] $Token
    )

    switch ($Source) {
        'Parameter' {
            if (-not $Token -or $Token.Length -eq 0) { return $null }
            return [System.Net.NetworkCredential]::new('', $Token).Password
        }
        'Session' {
            $connection = $__MtSession.GitHubConnection
            $header = $__MtSession.GitHubAuthHeader
            if (-not $connection -or -not $connection.Connected -or $header -isnot [System.Collections.IDictionary]) { return $null }
            if ([string]$connection.ApiBaseUri -ne 'https://api.github.com') { return $null }
            $expires = if ($connection.PSObject.Properties['TokenExpiresAt']) { $connection.TokenExpiresAt }
            if ($expires -and ([datetimeoffset]$expires) -le [datetimeoffset]::UtcNow) { return $null }
            $value = [string]$header['Authorization']
            if ($value -match '^Bearer\s+(\S+)$') { return $Matches[1] }
            return $null
        }
        'GitHubCli' { return Get-MtGitHubCliToken }
        'GH_TOKEN' { if ($env:GH_TOKEN) { return $env:GH_TOKEN } return $null }
        'GITHUB_TOKEN' { if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN } return $null }
    }
}
