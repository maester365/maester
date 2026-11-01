function Get-MtCisGitHubDeletionPolicyGap {
    <#
    .SYNOPSIS
    Internal: Checks for restrictive repository policies before failing an administrator baseline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Organization,
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [string] $RepositoryId
    )
    $query = @'
query DeletionPolicies($org:String!,$repo:String!,$after:String){
  repository(owner:$org,name:$repo){databaseId rulesets(first:100,after:$after,includeParents:true,targets:[REPOSITORY]){
    totalCount pageInfo{hasNextPage endCursor} nodes{
      id target enforcement
    }
  }}
}
'@
    $cursor = $null
    $seenCursors = [System.Collections.Generic.HashSet[string]]::new()
    $count = 0
    $seenPolicies = [System.Collections.Generic.HashSet[string]]::new()
    $expected = $null
    for ($page = 0; $page -lt 100; $page++) {
        try {
            $response = Invoke-MtGitHubGraphQLRequest -Query $query -OperationName DeletionPolicies -Variables @{ org = $Organization; repo = $Repository; after = $cursor }
        } catch {
            if ($_.Exception.Data['GitHubRateLimit']) { throw }
            if ((Get-MtGitHubErrorStatusCode -ErrorRecord $_) -in 403, 404) { return 'Applicable repository-policy evidence is not visible; a restrictive alternative cannot be ruled out.' }
            throw
        }
        $connection = $response.Data.repository.rulesets
        $databaseId = $response.Data.repository.databaseId
        if ($response.Errors.Count -gt 0 -or ($databaseId -isnot [int] -and $databaseId -isnot [long] -and $databaseId -isnot [bigint]) -or $databaseId -le 0 -or [string]$databaseId -cne $RepositoryId -or $null -eq $connection -or $connection.nodes -isnot [array] -or $connection.pageInfo.hasNextPage -isnot [bool] -or ($connection.totalCount -isnot [int] -and $connection.totalCount -isnot [long]) -or $connection.totalCount -lt 0) { return 'Applicable repository-policy evidence is unavailable or incomplete; a restrictive alternative cannot be ruled out.' }
        if ($null -eq $expected) { $expected = $connection.totalCount }
        if ($expected -ne $connection.totalCount) { return 'Applicable repository-policy population changed during collection.' }
        foreach ($policy in $connection.nodes) {
            if ($policy.id -isnot [string] -or [string]::IsNullOrWhiteSpace($policy.id) -or -not $seenPolicies.Add($policy.id) -or $policy.target -cne 'REPOSITORY') { return 'Applicable repository-policy identity or target is unusable.' }
            if ($policy.enforcement -cnotin 'ACTIVE', 'DISABLED', 'EVALUATE') { return 'Applicable repository-policy enforcement is unavailable or unknown.' }
            if ($policy.enforcement -cne 'ACTIVE') { continue }
            return 'An active repository-target policy may restrict deletion; its effective restrictions, bypass membership and stronger-policy equivalence need review.'
        }
        $count += $connection.nodes.Count
        if (-not $connection.pageInfo.hasNextPage) {
            if ($count -ne $expected) { return 'Applicable repository-policy total does not match collected items.' }
            return $null
        }
        $cursor = $connection.pageInfo.endCursor
        if ($cursor -isnot [string] -or [string]::IsNullOrWhiteSpace($cursor) -or -not $seenCursors.Add($cursor)) { return 'Applicable repository-policy pagination cursor is unusable.' }
    }
    return 'Applicable repository-policy pagination reached the page cap.'
}
