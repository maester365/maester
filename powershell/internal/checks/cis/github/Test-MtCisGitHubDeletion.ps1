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
    $report = @{
        Kind = $Kind; Field = $field; Setting = $org.$field; OrganizationId = $org.id
        ApiAuthority = ([uri]$__MtSession.GitHubConnection.ApiBaseUri).GetLeftPart([UriPartial]::Authority).ToLowerInvariant()
        MaximumOrganizationOwners = $MaximumOrganizationOwners; OwnerBranch = -not $org.$field
        Owners = @(); Repositories = @(); Gaps = @(); Message = ''
    }
    if (-not $org.$field) {
        $owners = Get-MtGitHubIdentityCollection -RelativeUri "/orgs/$encoded/members?role=admin" -Label 'Organization owner'
        $approvalsConfigured = $null -ne $policy -and $null -ne $policy.PSObject.Properties['ApprovedOwnerIds'] -and $policy.ApprovedOwnerIds.Count -gt 0
        $unapproved = @($owners.Items | Where-Object { $approvalsConfigured -and [string]$_.id -cnotin $policy.ApprovedOwnerIds })
        $report.Owners = $owners.Items
        $report.ApprovalsConfigured = $approvalsConfigured
        $report.ApprovedOwnerIds = $policy.ApprovedOwnerIds
        $report.OwnerComplete = $owners.Complete -and $owners.Items.Count -gt 0
        if (-not $owners.Complete -or $owners.Items.Count -eq 0) {
            $reason = if (-not $owners.Complete) { $owners.Gap } else { 'The organization-owner collection is unexpectedly empty.' }
            $report.Message = "Indeterminate: " + $reason
            Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity) -SkippedBecause Custom -SkippedCustomReason ("Indeterminate: " + $reason)
            return $null
        }
        if (-not $approvalsConfigured) {
            $instruction = if ($null -eq $policy) { 'Configure GlobalSettings.GitHubDeletionPolicy with ApprovedOwnerIds for the organization-owner branch.' } else { 'Configure a nonempty ApprovedOwnerIds roster for the organization-owner branch.' }
            $report.Message = $instruction + ' Observed membership does not approve a user as trusted and qualified.'
            Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
            return $null
        }
        $result = $owners.Items.Count -le $MaximumOrganizationOwners -and $unapproved.Count -eq 0
        $message = if ($result) { 'Well done. The complete organization-owner population is within the configured maximum and every owner is approved as trusted and qualified.' } else { 'Review organization owners: remove unnecessary owner assignments or explicitly approve trusted and qualified owners. Keep the live population within the configured maximum.' }
        $report.Message = $message
        Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $result
    }
    if ($null -eq $policy) {
        $report.Message = "Configure GlobalSettings.GitHubDeletionPolicy with the users approved as trusted and qualified. The observed $field value is $($org.$field); no approval population was supplied."
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    if ($policy.CompleteRepositoryInventory -ne $true -or -not $policy.PSObject.Properties['Repositories']) {
        $report.Message = 'Declare CompleteRepositoryInventory and approve administrators for every organization repository before assessing the administrator branch.'
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    $inventory = Get-MtGitHubRepositoryInventory
    if ($inventory.Issues.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason ('Indeterminate: organization repository inventory. ' + ($inventory.Issues -join ' '))
        return $null
    }
    if ($inventory.Repositories.Count -eq 0) {
        $report.Message = 'No repositories were visible. This does not establish a complete organization inventory or a not-applicable result.'
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    $declared = @{}
    foreach ($entry in $policy.Repositories) { $declared[$entry.Id] = $entry }
    $liveIds = @($inventory.Repositories | ForEach-Object { [string]$_.id })
    if (@($liveIds | Where-Object { -not $declared.ContainsKey($_) }).Count -or @($declared.Keys | Where-Object { $_ -cnotin $liveIds }).Count) {
        $report.Message = 'The declared repository IDs and the complete live inventory do not match. Reconcile missing, inaccessible, newly created or removed repositories; no exclusions are supported.'
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    if (@($policy.Repositories | Where-Object { $_.ApprovedAdministratorIds.Count -eq 0 }).Count) {
        $report.Message = 'Configure a nonempty ApprovedAdministratorIds roster for every repository. Empty approval rosters do not establish an assessed trust decision.'
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    $rows = [System.Collections.Generic.List[object]]::new()
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
        $rows.Add([pscustomobject]@{
            Name = $repository.name; AdministratorCount = $administrators.Count
            UnapprovedIds = @($unapproved | ForEach-Object { [string]$_.id }); Complete = $true
            Assessment = if ($conforms) { 'Meets baseline' } else { 'Needs review' }
        })
        if (-not $conforms) { $violations.Add($repository) }
    }
    $report.Repositories = $rows.ToArray()
    if ($Kind -eq 'Issue' -and $violations.Count -eq 0) {
        $roleGap = Get-MtCisGitHubDeletionRoleGap -Organization $organization
        if ($roleGap) {
            $report.Gaps = @($roleGap)
            Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
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
            $report.Gaps = @($policyGaps | Select-Object -Unique)
            Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
            return $null
        }
    }
    $result = $violations.Count -eq 0
    $message = if ($result) { 'Well done. Every repository in the declared complete organization inventory has exactly two effective administrators, both approved as trusted and qualified.' } else { 'Review repository administrator access: at least one repository does not have exactly two effective administrators, both approved as trusted and qualified.' }
    $report.Message = $message
    $report.Gaps = @($policyGaps | Select-Object -Unique)
    Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
    return $result
}
