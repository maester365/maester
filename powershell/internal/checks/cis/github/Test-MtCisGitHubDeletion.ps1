function Test-MtCisGitHubDeletion {
    <#
    .SYNOPSIS
    Internal: Assesses the configured owner or repository-administrator deletion branch.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [ValidateSet('Repository', 'Issue')] [string] $Kind,
        [ValidateRange(1, 2147483647)] [int] $MaximumOrganizationOwners = 3
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
        $report.Owners = $owners.Items
        $report.ApprovalsConfigured = $approvalsConfigured
        $report.ApprovedOwnerIds = $policy.ApprovedOwnerIds
        $report.OwnerComplete = $owners.Complete -and $owners.Items.Count -gt 0
        if (-not $report.OwnerComplete) {
            $report.Gaps += if (-not $owners.Complete) { $owners.Gap } else { 'The organization-owner collection is unexpectedly empty.' }
        }
        if (-not $approvalsConfigured) {
            $report.Gaps += 'Configure a nonempty ApprovedOwnerIds roster in GlobalSettings.GitHubDeletionPolicy. Observed membership does not approve a user as trusted and qualified.'
        }
        if ($owners.ExecutionError) {
            $report.Message = 'The owner collection request failed. Retained rows are partial evidence; this assessment remains an execution error.'
            Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
            throw $owners.ExecutionError
        }
        $unapproved = @($owners.Items | Where-Object { $approvalsConfigured -and [string]$_.id -cnotin $policy.ApprovedOwnerIds })
        # Counts from partial collections are lower bounds: enough to disprove the maximum,
        # but never enough to establish compliance or infer that an unseen user is approved.
        if ($approvalsConfigured -and ($owners.Items.Count -gt $MaximumOrganizationOwners -or $unapproved.Count -gt 0)) {
            $report.Message = 'Review organization owners: the validated population exceeds the configured Maester maximum or includes an owner outside the configured approval roster. Remove unnecessary assignments or explicitly approve trusted and qualified owners within the maximum. Any additional evidence gaps do not negate this observed violation.'
            Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
            return $false
        }
        if (-not $report.OwnerComplete) {
            $report.Message = 'Indeterminate: the complete organization-owner population could not be established.'
            Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity) -SkippedBecause Custom -SkippedCustomReason ('Indeterminate: ' + ($report.Gaps -join ' '))
            return $null
        }
        if (-not $approvalsConfigured) {
            $report.Message = 'Organization owners have been collected, but approvals have not been configured. Configure approvals before assessing owner counts and access.'
            Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
            return $null
        }
        $report.Message = 'Well done. The complete organization-owner population is within the configured maximum and every owner is approved as trusted and qualified.'
        Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $true
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    $violations = [System.Collections.Generic.List[object]]::new()
    $collectionGaps = [System.Collections.Generic.List[string]]::new()
    $scopeGaps = [System.Collections.Generic.List[string]]::new()
    $policyGaps = [System.Collections.Generic.List[string]]::new()
    $declared = @{}
    foreach ($entry in $policy.Repositories) { $declared[$entry.Id] = $entry }
    if ($null -eq $policy) {
        $scopeGaps.Add('Configure GlobalSettings.GitHubDeletionPolicy with a complete repository inventory and users approved as trusted and qualified. No approval population was supplied.')
    } else {
        if ($policy.CompleteRepositoryInventory -ne $true) { $scopeGaps.Add('Declare CompleteRepositoryInventory to confirm that the assessor has accounted for every organization repository.') }
        if (-not $policy.PSObject.Properties['Repositories']) { $scopeGaps.Add('Declare Repositories and approve administrators for every organization repository.') }
    }
    $confirmedViolations = 0
    try {
        $inventory = Get-MtGitHubRepositoryInventory
        foreach ($issue in $inventory.Issues) { $collectionGaps.Add("Organization repository inventory: $issue") }
        if ($inventory.Repositories.Count -eq 0 -and $inventory.Issues.Count -eq 0) {
            $scopeGaps.Add('No repositories were visible. This does not establish a complete organization inventory or a not-applicable result.')
        }
        $liveIds = @($inventory.Repositories | ForEach-Object { [string]$_.id })
        if ($null -ne $policy -and $policy.PSObject.Properties['Repositories'] -and (@($liveIds | Where-Object { -not $declared.ContainsKey($_) }).Count -or @($declared.Keys | Where-Object { $_ -cnotin $liveIds }).Count)) {
            $scopeGaps.Add('The declared repository IDs and the observed inventory do not match. Reconcile missing, inaccessible, newly created or removed repositories; no exclusions are supported.')
        }
        foreach ($repository in $inventory.Repositories) {
            $approvalsConfigured = $declared.ContainsKey([string]$repository.id) -and $declared[[string]$repository.id].ApprovedAdministratorIds.Count -gt 0
            if (-not $approvalsConfigured) {
                $scopeGaps.Add("$(Get-MtSafeMarkdown $repository.name): Configure a nonempty ApprovedAdministratorIds roster before assessing administrator access.")
                $rows.Add([pscustomobject]@{
                    Name = $repository.name; AdministratorCount = $null; UnapprovedIds = @()
                    Complete = $null; ApprovalsConfigured = $false; Assessment = 'Not assessed'
                })
                continue
            }
            $name = [uri]::EscapeDataString($repository.name)
            $collaborators = Get-MtGitHubIdentityCollection -RelativeUri "/repos/$encoded/$name/collaborators?affiliation=all" -Label 'Repository collaborator'
            $complete = $collaborators.Complete -and $collaborators.Items.Count -gt 0 -and @($collaborators.Items | Where-Object { $_.permissions.admin -isnot [bool] }).Count -eq 0
            if (-not $complete) {
                $reason = if (-not $collaborators.Complete) { $collaborators.Gap } elseif ($collaborators.Items.Count -eq 0) { 'The effective collaborator collection is unexpectedly empty; organization-owner access should be represented.' } else { 'Required collaborator permissions.admin is missing or not Boolean.' }
                $collectionGaps.Add("$(Get-MtSafeMarkdown $repository.name): $reason")
            }
            $administrators = @($collaborators.Items | Where-Object { $_.permissions.admin -is [bool] -and $_.permissions.admin -eq $true -and [string]$_.id -cnotin $collaborators.ConflictingAdministratorIds })
            $unapproved = @($administrators | Where-Object { $approvalsConfigured -and [string]$_.id -cnotin $declared[[string]$repository.id].ApprovedAdministratorIds })
            $violation = $administrators.Count -gt 2 -or $unapproved.Count -gt 0 -or ($complete -and $administrators.Count -lt 2)
            $rows.Add([pscustomobject]@{
                Name = $repository.name; AdministratorCount = $administrators.Count
                UnapprovedIds = @($unapproved | ForEach-Object { [string]$_.id }); Complete = $complete; ApprovalsConfigured = $approvalsConfigured
                Assessment = if ($violation) { 'Needs review' } elseif (-not $complete) { 'Indeterminate' } elseif (-not $approvalsConfigured) { 'Approvals not configured' } else { 'Meets baseline' }
            })
            if ($violation) { $violations.Add($repository) }
            if ($collaborators.ExecutionError) { throw $collaborators.ExecutionError }
        }
        if ($Kind -eq 'Repository') {
            foreach ($repository in $violations) {
                $gap = Get-MtCisGitHubDeletionPolicyGap -Organization $organization -Repository $repository.name -RepositoryId ([string]$repository.id)
                if ($gap) { $policyGaps.Add("$(Get-MtSafeMarkdown $repository.name): $gap") } else { $confirmedViolations++ }
            }
        } else {
            $confirmedViolations = $violations.Count
            # Additive issue permissions cannot remove an already validated violation. Do not
            # traverse optional catalogs to look past unusable required population evidence.
            if ($violations.Count -eq 0 -and $collectionGaps.Count -eq 0 -and $scopeGaps.Count -eq 0) {
                $roleGap = Get-MtCisGitHubDeletionRoleGap -Organization $organization
                if ($roleGap) { $policyGaps.Add($roleGap) }
            }
        }
    } catch {
        $report.Repositories = $rows.ToArray()
        $report.Gaps = @($collectionGaps.ToArray()) + @($scopeGaps.ToArray()) + @($policyGaps.ToArray())
        $report.Message = 'A GitHub evidence request or parsing operation failed. Collected repository observations are retained, but this assessment remains an execution error.'
        Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        # Do not expose an original exception's partial response, raw user IDs or arbitrary
        # server text through ErrorRecord, ReasonDetail or alternative report metadata.
        $message = if ($_.Exception.Data['GitHubRateLimit'] -or $_.Exception.Message -eq 'GitHub rate limit stopped identity collection.') { 'GitHub rate limit stopped deletion assessment.' } else { 'GitHub deletion evidence request or JSON parsing failed.' }
        throw [System.InvalidOperationException]::new($message)
    }
    $report.Repositories = $rows.ToArray()
    $report.Gaps = @($collectionGaps.ToArray()) + @($scopeGaps.ToArray()) + @($policyGaps.ToArray())
    if ($confirmedViolations -gt 0) {
        $report.Message = 'Review repository administrator access: at least one repository has a confirmed count or approval violation. Require exactly two effective administrators, both approved as trusted and qualified. Additional evidence gaps do not negate the confirmed violation.'
        Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $false
    }
    # Without a confirmed violation, incomplete required populations retain Skipped
    # even when optional policy uncertainty also remains. All gaps stay in the report.
    if ($collectionGaps.Count -gt 0) {
        $report.Message = 'Indeterminate: a usable complete repository inventory or effective administrator population could not be established.'
        Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity) -SkippedBecause Custom -SkippedCustomReason ('Indeterminate: ' + ($collectionGaps -join ' '))
        return $null
    }
    if ($scopeGaps.Count -gt 0 -or $policyGaps.Count -gt 0) {
        $report.Message = 'Investigate the outstanding repository inventory, approval or permission-policy gaps before determining compliance.'
        Add-MtTestResultDetail -Investigate -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
        return $null
    }
    $report.Message = 'Well done. Every repository in the declared complete organization inventory has exactly two effective administrators, both approved as trusted and qualified.'
    Add-MtTestResultDetail -Result (Get-MtCisGitHubDeletionResult -Evidence $report) -RedactedResult (Get-MtCisGitHubDeletionResult -Evidence $report -RedactUserIdentity)
    return $true
}
