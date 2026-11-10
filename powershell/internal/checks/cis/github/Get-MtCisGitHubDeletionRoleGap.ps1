function Get-MtCisGitHubDeletionRoleGap {
    <#
    .SYNOPSIS
    Internal: Qualifies whether custom role definitions extend issue deletion beyond administrators.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Organization)

    $encoded = [uri]::EscapeDataString($Organization)
    foreach ($catalog in @(@{ Path = 'custom-repository-roles'; Key = 'custom_roles' }, @{ Path = 'organization-roles'; Key = 'roles' })) {
        try {
            $evidence = Invoke-MtGitHubRequest -RelativeUri "/orgs/$encoded/$($catalog.Path)" -IncludeMetadata -ApiVersion '2026-03-10'
        } catch {
            if ($_.Exception.Data['GitHubRateLimit']) { throw }
            if ((Get-MtGitHubErrorStatusCode -ErrorRecord $_) -in 403, 404) { return 'Issue-deletion custom-role catalog is not visible to the connected account.' }
            throw
        }
        $data = $evidence.Data
        $roles = $data.($catalog.Key)
        if (-not $evidence.CollectionIntegrityValid -or $evidence.ContentKind -ne 'Object' -or $roles -isnot [array] -or ($data.total_count -isnot [int] -and $data.total_count -isnot [long]) -or $data.total_count -ne $roles.Count) {
            return 'Issue-deletion custom-role catalog is incomplete or has an unexpected API shape.'
        }
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($role in $roles) {
            if ($role -isnot [pscustomobject] -or ($role.id -isnot [int] -and $role.id -isnot [long] -and $role.id -isnot [bigint]) -or $role.id -le 0 -or -not $seen.Add([string]$role.id) -or $role.permissions -isnot [array] -or @($role.permissions | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count) { return 'Issue-deletion custom-role permissions or identities are unavailable or malformed.' }
            if ($catalog.Key -eq 'custom_roles') {
                if ($role.base_role -isnot [string] -or $role.base_role -cnotin 'read', 'triage', 'write', 'maintain') { return 'Issue-deletion custom repository role has an unavailable or unknown base role.' }
            } elseif ($null -ne $role.base_role -and ($role.base_role -isnot [string] -or $role.base_role -cnotin 'none', 'read', 'triage', 'write', 'maintain', 'admin')) {
                return 'Issue-deletion organization role has an unknown base role.'
            }
            # Additional issue-deletion grants require assignment evidence beyond the administrator population.
            if (@($role.permissions | Where-Object { $_ -match '(?i)(delete.*issue|issue.*delete)' }).Count) { return 'A custom role can grant issue deletion; its effective assignments and policy restrictions need review.' }
        }
    }
    return $null
}
