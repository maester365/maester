function Get-MtGitHubRepositoryInventory {
    <#
    .SYNOPSIS
    Internal: Enumerates organization repositories without visibility or archived-state filtering.
    #>
    [CmdletBinding()]
    param()
    $organization = $__MtSession.GitHubConnection.Organization
    $encoded = [uri]::EscapeDataString($organization)
    $evidence = Invoke-MtGitHubRequest -RelativeUri "/orgs/$encoded/repos?type=all" -Paginate -ApiVersion '2026-03-10' -IncludeMetadata
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($issue in $evidence.Issues) { $issues.Add($issue) }
    if (-not $evidence.PaginationComplete) { $issues.Add('Repository pagination is incomplete.') }
    $repositories = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($repository in $evidence.Data) {
        $id = $repository.id
        $numeric = $id -is [int] -or $id -is [long] -or $id -is [bigint]
        if (($null -eq $repository -or $repository.GetType() -ne [System.Management.Automation.PSCustomObject]) -or -not $numeric -or $id -le 0 -or $repository.name -isnot [string] -or [string]::IsNullOrWhiteSpace($repository.name) -or $null -eq $repository.owner -or $repository.owner.GetType() -ne [System.Management.Automation.PSCustomObject] -or $repository.owner.login -isnot [string] -or $repository.owner.login -ne $organization -or $repository.full_name -isnot [string] -or $repository.full_name -ne "$organization/$($repository.name)") {
            $issues.Add('Repository inventory contains an unusable identity.'); continue
        }
        if (-not $seen.Add([string]$id)) { $issues.Add('Repository inventory contains a duplicate ID.'); continue }
        $repositories.Add($repository)
    }
    return [pscustomobject]@{ Repositories = $repositories.ToArray(); Issues = $issues.ToArray(); StartedUtc = $evidence.StartedUtc; CompletedUtc = $evidence.CompletedUtc }
}
