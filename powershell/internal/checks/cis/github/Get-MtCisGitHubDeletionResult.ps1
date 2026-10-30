function Get-MtCisGitHubDeletionResult {
    <#
    .SYNOPSIS
    Internal: Renders raw or pseudonymized deletion results from the same evidence.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Evidence,
        [switch] $RedactUserIdentity
    )

    $userId = {
        param($Id)
        if ($RedactUserIdentity) {
            # User database IDs are host-scoped. Normalize the API authority, including a
            # non-default port, without adding numeric IDs to the global replacement map.
            $authority = ([uri]$Evidence.ApiAuthority).GetLeftPart([UriPartial]::Authority).ToLowerInvariant()
            Get-MtAffectedObjectUniqueId -System 'GitHub' -Type 'User' -Id "$authority/users/$Id"
        } else { [string]$Id }
    }
    $result = $Evidence.Message + "`n`nOrganization setting ``$($Evidence.Field)``: ``$($Evidence.Setting)``.`n`n"
    if ($Evidence.OwnerBranch) {
        $rows = [System.Collections.Generic.List[string]]::new()
        $unapproved = 0
        foreach ($owner in $Evidence.Owners) {
            $id = & $userId $owner.id
            $login = if ($RedactUserIdentity) { $id } elseif ($owner.login -is [string] -and -not [string]::IsNullOrWhiteSpace($owner.login)) { Get-MtSafeMarkdown $owner.login } else { 'Unavailable' }
            $approval = if (-not $Evidence.ApprovalsConfigured) { 'Not configured' } elseif ([string]$owner.id -cin $Evidence.ApprovedOwnerIds) { 'Approved' } else { 'Not approved' }
            if ($approval -eq 'Not approved') { $unapproved++ }
            $rows.Add("| $login | $id | $approval |")
        }
        $coverage = if ($Evidence.OwnerComplete) { 'Complete' } else { 'Incomplete / partial; total owner count unknown; observed count is a lower bound' }
        $unapprovedCount = if ($Evidence.ApprovalsConfigured) { [string]$unapproved } else { 'Not configured' }
        $result += "Organization ID: ``$($Evidence.OrganizationId)``.`n`n| Observed owners | Maximum | Unapproved owners | Evidence |`n| --- | --- | --- | --- |`n| $($rows.Count) | $($Evidence.MaximumOrganizationOwners) | $unapprovedCount | $coverage |`n`n| Owner login | User ID | Approval |`n| --- | --- | --- |`n" + ($rows -join "`n")
        if ($rows.Count -eq 0) { $result += "`nNo validated owner rows were available. This does not establish that the organization has no owners." }
        $result += "`n`nThe maximum is a Maester policy choice (default 3, configurable from 1 to 3); CIS does not define a numeric value for 'few'. Unassigned approval entries do not affect the live count."
    } else {
        $rows = foreach ($repository in $Evidence.Repositories) {
            $ids = @($repository.UnapprovedIds | ForEach-Object { & $userId $_ }) -join ', '
            $coverage = if ($repository.Complete) { 'Complete' } else { 'Incomplete / partial; observed count is a lower bound' }
            "| $(Get-MtSafeMarkdown $repository.Name) | $($repository.AdministratorCount) | $(@($repository.UnapprovedIds).Count) | $ids | $($repository.Assessment) | $coverage |"
        }
        $result += "| Repository | Effective administrators | Unapproved | Unapproved observed user IDs | Assessment | Evidence |`n| --- | --- | --- | --- | --- | --- |`n" + ($rows -join "`n")
        $result += "`n`nEffective administrator permissions include inherited grants. This assessment uses the configured approvals; it does not independently determine a person's trust or qualifications. No issue was deleted or sampled."
    }
    if ($Evidence.Gaps.Count) { $result += "`n`n" + ($Evidence.Gaps -join "`n`n") }
    return $result
}
