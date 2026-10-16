function Get-MtGitHubCacheKey {
    <#
    .SYNOPSIS
    Internal: Builds the per-session GitHub REST cache key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string] $AbsoluteUri
    )

    return "$ApiVersion|$AbsoluteUri"
}
