function Get-MtGitHubRepositoryInventory {
    <#
    .SYNOPSIS
    Internal: Enumerates organization repositories without visibility or archived-state filtering.
    #>
    [CmdletBinding()]
    param()
    $organization = $__MtSession.GitHubConnection.Organization
    $encoded = [uri]::EscapeDataString($organization)
    $evidence = Invoke-MtGitHubRequest -RelativeUri "/orgs/$encoded/repos?type=all" -Paginate -ApiVersion '2026-03-10' -IncludeMetadata -MaxPages 100
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($issue in $evidence.Issues) { $issues.Add($issue) }
    if (-not $evidence.CollectionIntegrityValid -or $evidence.ContentKind -ne 'Array' -or $evidence.Data -isnot [array]) { $issues.Add('Repository inventory is incomplete or has an unexpected API shape.') }
    if (-not $evidence.PaginationComplete) { $issues.Add('Repository pagination is incomplete.') }
    $repositories = [System.Collections.Generic.List[object]]::new()
    $seenIds = @{}
    $seenPaths = @{}
    $conflictingIds = [System.Collections.Generic.HashSet[string]]::new()
    $items = @()
    if ($evidence.Data -is [array]) { $items = $evidence.Data }
    foreach ($repository in $items) {
        $id = $repository.id
        $numeric = $id -is [int] -or $id -is [long] -or $id -is [bigint]
        if (($null -eq $repository -or $repository.GetType() -ne [System.Management.Automation.PSCustomObject]) -or -not $numeric -or $id -le 0 -or $repository.name -isnot [string] -or [string]::IsNullOrWhiteSpace($repository.name) -or $null -eq $repository.owner -or $repository.owner.GetType() -ne [System.Management.Automation.PSCustomObject] -or $repository.owner.login -isnot [string] -or $repository.owner.login -ne $organization -or $repository.full_name -isnot [string] -or $repository.full_name -ne "$organization/$($repository.name)") {
            $issues.Add('Repository inventory contains an unusable identity.')
            # A usable companion must not win by arriving first when the same numeric ID
            # has an invalid or foreign owner/path association elsewhere in the inventory.
            if ($numeric -and $id -gt 0) { $null = $conflictingIds.Add([string]$id) }
            continue
        }
        $key = [string]$id
        $path = $repository.full_name
        # Paths are case-insensitive on GitHub. Register every valid association, even
        # for a duplicate ID, so all IDs sharing an ambiguous path are excluded.
        if ($seenPaths.ContainsKey($path) -and $seenPaths[$path] -cne $key) {
            $issues.Add('Repository inventory maps the same repository path to different IDs.')
            $null = $conflictingIds.Add($seenPaths[$path])
            $null = $conflictingIds.Add($key)
        } else { $seenPaths[$path] = $key }
        if ($seenIds.ContainsKey($key)) {
            $issues.Add('Repository inventory contains a duplicate ID.')
            if ($seenIds[$key] -ne $path) {
                $issues.Add('Repository inventory maps the same ID to different repository paths.')
                $null = $conflictingIds.Add($key)
            }
            continue
        }
        $seenIds[$key] = $path
        $repositories.Add($repository)
    }
    return [pscustomobject]@{ Repositories = @($repositories | Where-Object { [string]$_.id -cnotin $conflictingIds }); Issues = @($issues | Select-Object -Unique); StartedUtc = $evidence.StartedUtc; CompletedUtc = $evidence.CompletedUtc }
}
