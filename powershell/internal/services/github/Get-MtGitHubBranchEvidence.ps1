function Get-MtGitHubBranchEvidence {
    <#
    .SYNOPSIS
    Internal: Reads one independently usable branch evidence dependency.
    .DESCRIPTION
    Only policy/branch 404 responses are contextualized. Other transport failures propagate to the selected check.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Repository,
        [Parameter(Mandatory)] [ValidateSet('Protection', 'StatusChecks', 'Signatures', 'Branch', 'Rules', 'Repository', 'Branches')] [string] $Kind,
        [string] $Branch
    )
    $owner = [uri]::EscapeDataString($Repository.owner.login)
    $name = [uri]::EscapeDataString($Repository.name)
    $prefix = "/repos/$owner/$name"
    $encodedBranch = [uri]::EscapeDataString($Branch)
    $path = switch ($Kind) {
        Protection { "$prefix/branches/$encodedBranch/protection" }
        StatusChecks { "$prefix/branches/$encodedBranch/protection/required_status_checks" }
        Signatures { "$prefix/branches/$encodedBranch/protection/required_signatures" }
        Branch { "$prefix/branches/$encodedBranch" }
        Rules { "$prefix/rules/branches/$encodedBranch" }
        Repository { $prefix }
        Branches { "$prefix/branches" }
    }
    try {
        $evidence = Invoke-MtGitHubRequest -RelativeUri $path -Paginate:($Kind -in 'Rules', 'Branches') -ApiVersion '2026-03-10' -IncludeMetadata
    } catch {
        if ($Kind -in 'Protection', 'StatusChecks', 'Signatures', 'Branch' -and $_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return [pscustomobject]@{ State = 'NotFoundOrNotVisible'; Data = $null; Detail = 'HTTP 404 does not distinguish absent policy, changed branch, or unavailable access.'; StartedUtc = $null; CompletedUtc = $null }
        }
        throw
    }
    $valid = $evidence.CollectionIntegrityValid -and -not $evidence.AccessLimited
    if ($Kind -in 'Rules', 'Branches') { $valid = $valid -and $evidence.PaginationComplete } else { $valid = $valid -and $evidence.ContentKind -eq 'Object' }
    return [pscustomobject]@{
        State = $(if ($valid) { 'Available' } else { 'Indeterminate' })
        Data = $evidence.Data
        Detail = $evidence.Issues -join ' '
        StartedUtc = $evidence.StartedUtc
        CompletedUtc = $evidence.CompletedUtc
    }
}
