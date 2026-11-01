function Get-MtGitHubIdentityCollection {
    <#
    .SYNOPSIS
    Internal: Collects validated distinct identities without discarding usable partial evidence.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RelativeUri,
        [Parameter(Mandatory)] [string] $Label
    )
    $executionError = $null
    try {
        $evidence = Invoke-MtGitHubRequest -RelativeUri $RelativeUri -Paginate -IncludeMetadata -ApiVersion '2026-03-10' -MaxPages 100
    } catch {
        # The transport keeps earlier pages on errors. Retain their validated identities in the
        # result Markdown, but never attach the raw response or server text to exported errors.
        $partial = $_.Exception.Data['GitHubPartialResponse']
        $evidence = [pscustomobject]@{ Data = $partial.Data; ContentKind = 'Array'; CollectionIntegrityValid = $false; PaginationComplete = $false }
        $message = if ($_.Exception.Data['GitHubRateLimit']) { 'GitHub rate limit stopped identity collection.' } else { 'GitHub identity collection request or JSON parsing failed.' }
        $executionError = [System.InvalidOperationException]::new($message)
    }
    $gaps = [System.Collections.Generic.List[string]]::new()
    if (-not $evidence.CollectionIntegrityValid -or -not $evidence.PaginationComplete -or $evidence.ContentKind -ne 'Array' -or $evidence.Data -isnot [array]) {
        $gaps.Add("$Label collection is incomplete or has an unexpected API shape.")
    }
    $items = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    $conflicts = [System.Collections.Generic.HashSet[string]]::new()
    if ($evidence.Data -is [array]) {
        foreach ($item in $evidence.Data) {
            if ($item -isnot [pscustomobject] -or ($item.id -isnot [int] -and $item.id -isnot [long] -and $item.id -isnot [bigint]) -or $item.id -le 0) {
                $gaps.Add("$Label collection contains an invalid identity.")
                continue
            }
            $id = [string]$item.id
            if ($seen.ContainsKey($id)) {
                $gaps.Add("$Label collection contains a duplicate identity.")
                $previous = $seen[$id]
                # A duplicate cannot increase the population. Conflicting or unusable permission
                # observations for the same ID cannot establish an effective administrator either.
                if ($previous.permissions.admin -isnot [bool] -or $item.permissions.admin -isnot [bool] -or $previous.permissions.admin -ne $item.permissions.admin) {
                    $null = $conflicts.Add($id)
                }
                continue
            }
            $seen[$id] = $item
            $items.Add($item)
        }
    }
    return [pscustomobject]@{
        Complete = $gaps.Count -eq 0
        Items = $items.ToArray()
        ConflictingAdministratorIds = @($conflicts)
        Gap = ($gaps | Select-Object -Unique) -join ' '
        ExecutionError = $executionError
    }
}
