function Get-MtGitHubIdentityCollection {
    <#
    .SYNOPSIS
    Internal: Collects and validates a bounded GitHub REST identity collection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RelativeUri,
        [Parameter(Mandatory)] [string] $Label
    )
    $evidence = Invoke-MtGitHubRequest -RelativeUri $RelativeUri -Paginate -IncludeMetadata -ApiVersion '2026-03-10' -MaxPages 100
    if (-not $evidence.CollectionIntegrityValid -or -not $evidence.PaginationComplete -or $evidence.ContentKind -ne 'Array' -or $evidence.Data -isnot [array]) {
        return [pscustomobject]@{ Complete = $false; Items = @(); Gap = "$Label collection is incomplete or has an unexpected API shape." }
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in $evidence.Data) {
        if ($item -isnot [pscustomobject] -or ($item.id -isnot [int] -and $item.id -isnot [long] -and $item.id -isnot [bigint]) -or $item.id -le 0 -or -not $seen.Add([string]$item.id)) {
            return [pscustomobject]@{ Complete = $false; Items = @(); Gap = "$Label collection contains an invalid or duplicate identity." }
        }
    }
    return [pscustomobject]@{ Complete = $true; Items = $evidence.Data; Gap = $null }
}
