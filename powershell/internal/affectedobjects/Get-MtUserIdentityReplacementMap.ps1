function Get-MtUserIdentityReplacementMap {
    <#
    .SYNOPSIS
    Builds the map of user identity values (display name, UPN, object id) to redact from generated reports.

    .DESCRIPTION
    Uses the affected objects attached to the Maester results to find every user object and maps
    that user's display name (or UPN) and object id to the object's stable UniqueId, so reports
    remain correlatable across runs. The token is a pseudonym, not anonymization: see Get-MtAffectedObjectUniqueId.

    Handles both single-tenant results and merged multi-tenant results (Tenants property).

    Redaction is best effort: only users that were captured in the affected objects can be
    redacted. Text that names a user without the run referencing that object is not detected.

    With -IncludeSessionCache the users in the cached Graph responses of the current session are
    added too (top-level objects and list 'value' items that carry both id and userPrincipalName).
    This covers users that a check only read as part of a list, such as the member users that
    MT.1033 puts in its test titles. Only their UPN and id are mapped, not their display name.

    The signed-in account (Account and MgContext.Account) is always mapped, because every report
    carries it whether or not the run read that user from Graph. When the account was also read
    from Graph, the token of its object id is reused.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # The Maester results object to scan for user objects.
        [Parameter(Mandatory = $true)]
        [psobject] $MaesterResults,

        # Also map users found in the Graph responses cached by the current session.
        [Parameter(Mandatory = $false)]
        [switch] $IncludeSessionCache
    )

    $tenants = if ($MaesterResults.PSObject.Properties.Name -contains 'Tenants') {
        @($MaesterResults.Tenants)
    } else {
        @($MaesterResults)
    }

    $replacements = @{}
    $addUserObject = {
        param($affectedObject, [switch] $KeepExisting)
        $uniqueId = $affectedObject.UniqueId
        if ([string]::IsNullOrWhiteSpace($uniqueId) -and $affectedObject.Id) {
            $uniqueId = Get-MtAffectedObjectUniqueId -System $affectedObject.System -Type $affectedObject.Type -Id $affectedObject.Id
        }
        if ([string]::IsNullOrWhiteSpace($uniqueId)) { return }

        $values = @()
        # Very short display names would match unrelated substrings across the whole
        # report (a user called "Ed" would corrupt every word containing "ed"), so only
        # values long enough to be specific are redacted by substring replacement.
        if ($affectedObject.DisplayName -and ([string]$affectedObject.DisplayName).Length -ge 4) { $values += [string]$affectedObject.DisplayName }
        if ($affectedObject.Id) { $values += [string]$affectedObject.Id }
        $userPrincipalName = Get-ObjectProperty $affectedObject 'UserPrincipalName'
        if ($userPrincipalName) { $values += [string]$userPrincipalName }
        foreach ($value in $values) {
            if ($KeepExisting -and $replacements.ContainsKey($value)) { continue }
            $replacements[$value] = $uniqueId
        }
    }

    # A user the cache only saw by UPN (users/{upn}) has a UPN-derived token. Map those last so the
    # object id token wins and one user does not get two tokens depending on inventory order.
    $upnKeyedUsers = [System.Collections.Generic.List[object]]::new()
    foreach ($tenant in $tenants) {
        foreach ($affectedObject in @($tenant.AffectedObjects | Where-Object { $_.Type -eq 'User' })) {
            if (([string]$affectedObject.Id).Contains('@')) {
                $upnKeyedUsers.Add($affectedObject)
            } else {
                & $addUserObject $affectedObject
            }
        }
    }

    if ($IncludeSessionCache -and $__MtSession.GraphCache) {
        foreach ($response in @($__MtSession.GraphCache.Values)) {
            if ($null -eq $response -or $response -is [string]) { continue }
            foreach ($item in @($response) + @($response.value)) {
                if ($null -eq $item -or $item -is [string]) { continue }
                $userPrincipalName = [string]$item.userPrincipalName
                $id = [string]$item.id
                if (-not $userPrincipalName -or -not $id) { continue }

                # Same identity as the cache-derived inventory record, so both yield the same token.
                $uniqueId = Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id $id
                # Display names are skipped: a large list read brings in generic names such as "Support".
                if (-not $replacements.ContainsKey($userPrincipalName)) { $replacements[$userPrincipalName] = $uniqueId }
                if (-not $replacements.ContainsKey($id)) { $replacements[$id] = $uniqueId }
            }
        }
    }

    foreach ($affectedObject in $upnKeyedUsers) {
        & $addUserObject $affectedObject -KeepExisting
    }

    foreach ($tenant in $tenants) {
        foreach ($account in @($tenant.Account, $tenant.MgContext.Account)) {
            $userPrincipalName = [string]$account
            # App-only runs carry no account, and an unconnected run carries a placeholder text.
            if (-not $userPrincipalName.Contains('@') -or $replacements.ContainsKey($userPrincipalName)) { continue }
            $replacements[$userPrincipalName] = Get-MtAffectedObjectUniqueId -System 'EntraID' -Type 'User' -Id $userPrincipalName
        }
    }

    return $replacements
}
