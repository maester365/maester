function Resolve-MtGitHubDeletionPolicy {
    <#
    .SYNOPSIS
    Internal: Validates the assessor's GitHub deletion approval configuration and target binding.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Organization)

    $policy = Get-MtSetting -Name GitHubDeletionPolicy -Verbose:$false
    if ($null -eq $policy -or ($policy -is [System.Collections.IDictionary] -and $policy.Count -eq 0) -or ($policy -is [pscustomobject] -and @($policy.PSObject.Properties).Count -eq 0)) { return $null }
    if ($policy -isnot [pscustomobject]) { throw 'GitHubDeletionPolicy must be a JSON object.' }
    $allowed = 'ApiBaseUri', 'OrganizationId', 'ApprovedOwnerIds', 'CompleteRepositoryInventory', 'Repositories'
    foreach ($property in $policy.PSObject.Properties.Name) {
        if ($property -notin $allowed) { throw 'GitHubDeletionPolicy contains an unknown property.' }
    }
    $base = $__MtSession.GitHubConnection.ApiBaseUri.TrimEnd('/')
    if ($policy.ApiBaseUri -isnot [string] -or $policy.ApiBaseUri.TrimEnd('/') -cne $base) { throw 'GitHubDeletionPolicy.ApiBaseUri must match the connected API base URI.' }
    $idPattern = '^[1-9][0-9]*$'
    if ($policy.OrganizationId -isnot [string] -or $policy.OrganizationId -cnotmatch $idPattern) { throw 'GitHubDeletionPolicy.OrganizationId must be a positive decimal ID string.' }
    if (($Organization.id -isnot [int] -and $Organization.id -isnot [long] -and $Organization.id -isnot [bigint]) -or $Organization.id -le 0) { throw 'GitHub organization identity is unavailable or unusable.' }
    if ($policy.OrganizationId -cne [string]$Organization.id) { throw 'GitHubDeletionPolicy.OrganizationId does not match the connected organization.' }
    foreach ($name in 'ApprovedOwnerIds') {
        if (-not $policy.PSObject.Properties[$name]) { continue }
        if ($policy.$name -isnot [array]) { throw "GitHubDeletionPolicy.$name must be an array of positive decimal ID strings." }
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($id in $policy.$name) {
            if ($id -isnot [string] -or $id -cnotmatch $idPattern -or -not $seen.Add($id)) { throw "GitHubDeletionPolicy.$name contains an invalid or duplicate ID." }
        }
    }
    if ($policy.PSObject.Properties['CompleteRepositoryInventory'] -and $policy.CompleteRepositoryInventory -isnot [bool]) { throw 'GitHubDeletionPolicy.CompleteRepositoryInventory must be Boolean.' }
    if ($policy.PSObject.Properties['Repositories']) {
        if ($policy.Repositories -isnot [array]) { throw 'GitHubDeletionPolicy.Repositories must be an array.' }
        $seenRepositories = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($repository in $policy.Repositories) {
            if ($repository -isnot [pscustomobject] -or $repository.Id -isnot [string] -or $repository.Id -cnotmatch $idPattern -or -not $seenRepositories.Add($repository.Id)) { throw 'GitHubDeletionPolicy.Repositories contains an invalid or duplicate repository ID.' }
            if (@($repository.PSObject.Properties.Name | Where-Object { $_ -notin 'Id', 'ApprovedAdministratorIds' }).Count) { throw 'A GitHubDeletionPolicy repository contains an unknown property.' }
            if ($repository.ApprovedAdministratorIds -isnot [array]) { throw 'Each GitHubDeletionPolicy repository needs ApprovedAdministratorIds as an array.' }
            $seenUsers = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($id in $repository.ApprovedAdministratorIds) {
                if ($id -isnot [string] -or $id -cnotmatch $idPattern -or -not $seenUsers.Add($id)) { throw 'ApprovedAdministratorIds contains an invalid or duplicate ID.' }
            }
        }
    }
    return $policy
}
