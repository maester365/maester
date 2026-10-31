function Test-MtCisGitHubDeletion {
    <#
    .SYNOPSIS
    Internal: Assesses the configured owner or repository-administrator deletion branch.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [ValidateSet('Repository', 'Issue')] [string] $Kind,
        [ValidateRange(1, 3)] [int] $MaximumOrganizationOwners = 3
    )
    if (-not $__MtSession.GitHubConnection -or $__MtSession.GitHubConnection.Connected -ne $true) { throw 'Not connected to GitHub. Call Connect-MtGitHub first.' }
    $organization = $__MtSession.GitHubConnection.Organization
    $encoded = [uri]::EscapeDataString($organization)
    $evidence = Invoke-MtGitHubRequest -RelativeUri "/orgs/$encoded" -IncludeMetadata -ApiVersion '2026-03-10'
    $org = $evidence.Data
    $field = if ($Kind -eq 'Repository') { 'members_can_delete_repositories' } else { 'members_can_delete_issues' }
    if (-not $evidence.CollectionIntegrityValid -or $evidence.ContentKind -ne 'Object' -or $org -isnot [pscustomobject] -or $org.$field -isnot [bool]) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Indeterminate: required GitHub organization field '$field' is unavailable, incomplete or not Boolean."
        return $null
    }
    if (($org.id -isnot [int] -and $org.id -isnot [long] -and $org.id -isnot [bigint]) -or $org.id -le 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Indeterminate: required GitHub organization identity is unavailable or unusable.'
        return $null
    }
    $policy = Resolve-MtGitHubDeletionPolicy -Organization $org
    if ($null -eq $policy) {
        Add-MtTestResultDetail -Investigate -Result "Configure GlobalSettings.GitHubDeletionPolicy with the users approved as trusted and qualified. The observed $field value is $($org.$field); no approval population was supplied."
        return $null
    }
    $heading = "Organization setting ``$field``: ``$($org.$field)``.`n`n"
    if (-not $org.$field) {
        if (-not $policy.PSObject.Properties['ApprovedOwnerIds'] -or $policy.ApprovedOwnerIds.Count -eq 0) {
            Add-MtTestResultDetail -Investigate -Result ($heading + 'Configure ApprovedOwnerIds for the organization-owner branch.')
            return $null
        }
        $owners = Get-MtGitHubIdentityCollection -RelativeUri "/orgs/$encoded/members?role=admin" -Label 'Organization owner'
        if (-not $owners.Complete -or $owners.Items.Count -eq 0) {
            $reason = if (-not $owners.Complete) { $owners.Gap } else { 'The organization-owner collection is unexpectedly empty.' }
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason ("Indeterminate: " + $reason)
            return $null
        }
        $unapproved = @($owners.Items | Where-Object { [string]$_.id -cnotin $policy.ApprovedOwnerIds })
        $result = $owners.Items.Count -le $MaximumOrganizationOwners -and $unapproved.Count -eq 0
        $message = if ($result) { 'Well done. The complete organization-owner population is within the configured maximum and every owner is approved as trusted and qualified.' } else { 'Review organization owners: remove unnecessary owner assignments or explicitly approve trusted and qualified owners. Keep the live population within the configured maximum.' }
        $details = "| Live owners | Maximum | Unapproved owners |`n| --- | --- | --- |`n| $($owners.Items.Count) | $MaximumOrganizationOwners | $($unapproved.Count) |"
        if ($unapproved.Count) { $details += "`n`nUnapproved observed owner IDs: " + (($unapproved | ForEach-Object { [string]$_.id }) -join ', ') + '.' }
        Add-MtTestResultDetail -Result ($message + "`n`n" + $heading + $details + "`n`nThe maximum is a Maester policy choice (default 3, configurable from 1 to 3); CIS does not define a numeric value for 'few'. Unassigned approval entries do not affect the live count.")
        return $result
    }
    if ($policy.CompleteRepositoryInventory -ne $true -or -not $policy.PSObject.Properties['Repositories']) {
        Add-MtTestResultDetail -Investigate -Result ($heading + 'Declare CompleteRepositoryInventory and approve administrators for every organization repository before assessing the administrator branch.')
        return $null
    }
    $inventory = Get-MtGitHubRepositoryInventory
    if ($inventory.Issues.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason ('Indeterminate: organization repository inventory. ' + ($inventory.Issues -join ' '))
        return $null
    }
    if ($inventory.Repositories.Count -eq 0) {
        Add-MtTestResultDetail -Investigate -Result ($heading + 'No repositories were visible. This does not establish a complete organization inventory or a not-applicable result.')
        return $null
    }
    $declared = @{}
    foreach ($entry in $policy.Repositories) { $declared[$entry.Id] = $entry }
    $liveIds = @($inventory.Repositories | ForEach-Object { [string]$_.id })
    if (@($liveIds | Where-Object { -not $declared.ContainsKey($_) }).Count -or @($declared.Keys | Where-Object { $_ -cnotin $liveIds }).Count) {
        Add-MtTestResultDetail -Investigate -Result ($heading + 'The declared repository IDs and the complete live inventory do not match. Reconcile missing, inaccessible, newly created or removed repositories; no exclusions are supported.')
        return $null
    }
    if (@($policy.Repositories | Where-Object { $_.ApprovedAdministratorIds.Count -eq 0 }).Count) {
        Add-MtTestResultDetail -Investigate -Result ($heading + 'Configure a nonempty ApprovedAdministratorIds roster for every repository. Empty approval rosters do not establish an assessed trust decision.')
        return $null
    }
    $rows = [System.Collections.Generic.List[string]]::new()
    $violations = [System.Collections.Generic.List[object]]::new()
    foreach ($repository in $inventory.Repositories) {
        $name = [uri]::EscapeDataString($repository.name)
        $collaborators = Get-MtGitHubIdentityCollection -RelativeUri "/repos/$encoded/$name/collaborators?affiliation=all" -Label 'Repository collaborator'
        if (-not $collaborators.Complete -or $collaborators.Items.Count -eq 0 -or @($collaborators.Items | Where-Object { $_.permissions.admin -isnot [bool] }).Count) {
            $reason = if (-not $collaborators.Complete) { $collaborators.Gap } elseif ($collaborators.Items.Count -eq 0) { 'The effective collaborator collection is unexpectedly empty; organization-owner access should be represented.' } else { 'Required collaborator permissions.admin is missing or not Boolean.' }
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason ("Indeterminate: " + $reason)
            return $null
        }
        $administrators = @($collaborators.Items | Where-Object { $_.permissions.admin -eq $true })
        $unapproved = @($administrators | Where-Object { [string]$_.id -cnotin $declared[[string]$repository.id].ApprovedAdministratorIds })
        $conforms = $administrators.Count -eq 2 -and $unapproved.Count -eq 0
        $unapprovedIds = ($unapproved | ForEach-Object { [string]$_.id }) -join ', '
        $rows.Add("| $(Get-MtSafeMarkdown $repository.name) | $($administrators.Count) | $($unapproved.Count) | $unapprovedIds | $(if ($conforms) { 'Meets baseline' } else { 'Needs review' }) |")
        if (-not $conforms) { $violations.Add($repository) }
    }
    $table = "| Repository | Effective administrators | Unapproved | Unapproved observed user IDs | Assessment |`n| --- | --- | --- | --- | --- |`n" + ($rows -join "`n")
    if ($Kind -eq 'Issue' -and $violations.Count -eq 0) {
        $roleGap = Get-MtCisGitHubDeletionRoleGap -Organization $organization
        if ($roleGap) {
            Add-MtTestResultDetail -Investigate -Result ($heading + $table + "`n`n" + $roleGap)
            return $null
        }
    }
    $policyGaps = [System.Collections.Generic.List[string]]::new()
    $confirmedViolations = 0
    if ($Kind -eq 'Repository') {
        foreach ($repository in $violations) {
            $gap = Get-MtCisGitHubDeletionPolicyGap -Organization $organization -Repository $repository.name -RepositoryId ([string]$repository.id)
            if ($gap) { $policyGaps.Add("$(Get-MtSafeMarkdown $repository.name): $gap") } else { $confirmedViolations++ }
        }
        if ($violations.Count -gt 0 -and $confirmedViolations -eq 0) {
            Add-MtTestResultDetail -Investigate -Result ($heading + $table + "`n`n" + (($policyGaps | Select-Object -Unique) -join "`n`n"))
            return $null
        }
    }
    $result = $violations.Count -eq 0
    $message = if ($result) { 'Well done. Every repository in the declared complete organization inventory has exactly two effective administrators, both approved as trusted and qualified.' } else { 'Review repository administrator access: at least one repository does not have exactly two effective administrators, both approved as trusted and qualified.' }
    $coverage = if ($policyGaps.Count) { "`n`nAdditional repositories remain unresolved: " + (($policyGaps | Select-Object -Unique) -join ' ') } else { '' }
    Add-MtTestResultDetail -Result ($message + "`n`n" + $heading + $table + $coverage + "`n`nEffective administrator permissions include inherited grants. This assessment uses the configured approvals; it does not independently determine a person’s trust or qualifications. No issue was deleted or sampled.")
    return $result
}
