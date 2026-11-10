function Resolve-MtCisGitHubRepositoryScope {
    <#
    .SYNOPSIS
    Internal: Reconciles explicit CIS applicability with the complete readable organization inventory.
    .DESCRIPTION
    Validates only classifications the selected control needs. The declaration is not proof of permission completeness.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Control)
    $provided = $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubCisRepositoryScope']
    if ($provided -and $null -ne $provided.Value -and $provided.Value.GetType() -ne [System.Management.Automation.PSCustomObject]) { throw 'GitHubCisRepositoryScope must be a configuration object.' }
    $scope = Get-MtSetting -Name GitHubCisRepositoryScope -Verbose:$false
    $issues = [System.Collections.Generic.List[string]]::new()
    $repositories = [System.Collections.Generic.List[object]]::new()
    if ($null -eq $scope -or ($scope -is [System.Collections.IDictionary] -and $scope.Count -eq 0) -or ($scope -is [pscustomobject] -and @($scope.PSObject.Properties).Count -eq 0)) {
        return [pscustomobject]@{ Repositories = @(); Issues = @('Configure a complete GitHubCisRepositoryScope applicability declaration.'); ExcludedCount = 0; Exclusions = @(); StartedUtc = $null; CompletedUtc = $null }
    }
    if (($null -eq $scope -or $scope.GetType() -ne [System.Management.Automation.PSCustomObject])) { throw 'GitHubCisRepositoryScope must be a configuration object.' }
    $organization = $__MtSession.GitHubConnection.Organization
    if ($scope.Organization -isnot [string] -or $scope.Organization -ne $organization) { throw 'GitHubCisRepositoryScope.Organization must match the connected organization.' }
    if ($scope.Complete -isnot [bool]) { throw 'GitHubCisRepositoryScope.Complete must be Boolean.' }
    if (-not $scope.Complete) { $issues.Add('The assessor has not declared this repository scope complete.') }
    if ($scope.Repositories -isnot [array]) { throw 'GitHubCisRepositoryScope.Repositories must be an array.' }
    $inventory = Get-MtGitHubRepositoryInventory
    foreach ($issue in $inventory.Issues) { $issues.Add($issue) }
    $byId = @{}
    foreach ($item in $inventory.Repositories) { $byId[[string]$item.id] = $item }
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $excluded = 0
    $exclusions = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $scope.Repositories) {
        if (($null -eq $entry -or $entry.GetType() -ne [System.Management.Automation.PSCustomObject]) -or ($entry.Id -isnot [int] -and $entry.Id -isnot [long] -and $entry.Id -isnot [bigint]) -or $entry.Id -le 0 -or $entry.InUse -isnot [bool]) { throw 'Every scope repository needs a numeric positive Id and Boolean InUse.' }
        $id = [string]$entry.Id
        if (-not $seen.Add($id)) { throw 'GitHubCisRepositoryScope contains a duplicate repository Id.' }
        if (-not $byId.ContainsKey($id)) { $issues.Add('A declared repository is missing or inaccessible in the live inventory.'); continue }
        if (-not $entry.InUse) {
            if ($entry.ExclusionReason -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.ExclusionReason)) { throw 'Every excluded repository needs an ExclusionReason.' }
            $exclusions.Add([pscustomobject]@{ Repository = $byId[$id].full_name; Reason = $entry.ExclusionReason })
            $excluded++; continue
        }
        $branches = [System.Collections.Generic.List[string]]::new()
        foreach ($field in @($(if ($Control -ne '1.1.12') { 'MainBranches' }), $(if ($Control -eq '1.1.16') { 'LongStandingBranches' }))) {
            if (-not $field) { continue }
            if (-not (Test-MtGitHubObjectProperty -InputObject $entry -PropertyName $field)) { $issues.Add("A required $field declaration is missing."); continue }
            if ($entry.$field -isnot [array]) { throw "GitHubCisRepositoryScope.$field must be an array." }
            if ($field -eq 'MainBranches' -and $entry.$field.Count -eq 0) { $issues.Add('An in-use repository has no main-branch classification.') }
            foreach ($branch in $entry.$field) {
                if ($branch -isnot [string] -or [string]::IsNullOrWhiteSpace($branch)) { throw "GitHubCisRepositoryScope.$field must contain nonempty branch-name strings." }
                if (-not $branches.Contains($branch)) { $branches.Add($branch) }
            }
        }
        $repositories.Add([pscustomobject]@{ Repository = $byId[$id]; Branches = $branches.ToArray() })
    }
    foreach ($id in $byId.Keys) { if (-not $seen.Contains($id)) { $issues.Add('A live repository has no applicability classification.') } }
    if ($inventory.Repositories.Count -eq 0) { $issues.Add('Empty repository inventory does not establish complete visibility or non-applicability.') }
    return [pscustomobject]@{ Repositories = $repositories.ToArray(); Issues = $issues.ToArray(); ExcludedCount = $excluded; Exclusions = $exclusions.ToArray(); StartedUtc = $inventory.StartedUtc; CompletedUtc = $inventory.CompletedUtc }
}
