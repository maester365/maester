function Clear-MtADCache {
    <#
    .SYNOPSIS
    Resets the local cache of Active Directory data. Use this if you need to force a refresh of the cache in the current session.

    .DESCRIPTION
    By default all Active Directory data is cached and re-used for the duration of the session.

    Use this function to clear the cache and force a refresh of the data from Active Directory.

    .PARAMETER Categories
    An array of cache categories to clear. Valid values are: Domain, FineGrainedPasswordPolicies, Forest, Computers, Users, Groups, ServiceAccounts, DomainControllers, ReplicationSites, Subnets, OptionalFeatures, ReplicationConnections, DfsrSubscriptions, Trusts, OrganizationalUnits, SmbConfigurations, DNS, Configuration, Schema, Printers, DaclEntries.

    .PARAMETER ComputerName
    The name of the computer whose DomainState entries should be cleared for the specified categories. If omitted, all computers are affected for the selected categories.

    .EXAMPLE
    Clear-MtADCache

    This example clears the cache of all Active Directory data.

    .EXAMPLE
    Clear-MtADCache -Categories Domain

    Clears only the Domain category cache entries for all computers.

    .EXAMPLE
    Clear-MtADCache -ComputerName DC01

    Clears only DomainState entries associated with ComputerName DC01 for all categories.

    .LINK
    https://maester.dev/docs/commands/Clear-MtADCache
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Setting module level variable')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Scoped cache clearing is performed in a controlled context for tests')]
    [CmdletBinding()]
    param(
        [ValidateSet('Domain','FineGrainedPasswordPolicies','Forest','Computers','Users','Groups','ServiceAccounts','DomainControllers','ReplicationSites','Subnets','OptionalFeatures','ReplicationConnections','DfsrSubscriptions','Trusts','OrganizationalUnits','SmbConfigurations','DNS','Configuration','Schema','Printers','DaclEntries')][string[]]$Categories,
        [string]$ComputerName
    )

    # Helper to safely remove a key from the AD cache (must be defined before use)
    function Remove-CacheKeyIfPresent {
        param([string]$Key)
        if (($null -ne $__MtSession) -and ($null -ne $__MtSession.ADCache) -and ($__MtSession.ADCache.ContainsKey($Key))) {
            $__MtSession.ADCache.Remove($Key) | Out-Null
        }
    }

    # NOTE: This function now supports scoped cache clearing. If no parameters
    # are provided, we preserve the original behavior (clear all AD caches).
    # When -Categories and/or -ComputerName are provided, we clear only the
    # targeted domain-state cache entries as described in Issue #2155.

    # When called with no parameters, keep legacy behavior
    if (-not $Categories -and -not $ComputerName) {
        Write-Verbose -Message "Clearing the results cached from Active Directory in this session"

        $__MtSession.ADCache = @{}
        $__MtSession.ADCollectionTime = $null
        return
    }

    # If ComputerName is provided without any Categories, perform a -ComputerName-only sweep
    if ($ComputerName -and -not $Categories) {
        foreach ($key in @($__MtSession.ADCache.Keys)) {
            if ($key -like "DomainState:*:$ComputerName") {
                Remove-CacheKeyIfPresent -Key $key
            }
        }
        # Remove legacy per-computer aggregate key
        Remove-CacheKeyIfPresent -Key "DomainState:$ComputerName"
        # Also clear the global legacy aggregate key to ensure a clean state when scoped by computer
        Remove-CacheKeyIfPresent -Key 'DomainState'
        return
    }

    # Categories validation is now handled by [ValidateSet] on the parameter

    # If categories are specified, perform scoped clearing
    if ($Categories) {
        foreach ($cat in $Categories) {
            if ($ComputerName) {
                # Per-cat, per-computer key only
                Remove-CacheKeyIfPresent -Key "DomainState:$($cat):$ComputerName"
            }
            else {
                # Global per-category key and all per-computer variants for this category
                Remove-CacheKeyIfPresent -Key "DomainState:$cat"
                foreach ($key in @($__MtSession.ADCache.Keys)) {
                    if ($key -like "DomainState:$($cat):*") {
                        Remove-CacheKeyIfPresent -Key $key
                    }
                }
            }
        }

        # Always remove legacy aggregate keys when a scoped clear occurs
        Remove-CacheKeyIfPresent -Key 'DomainState'
        if ($ComputerName) {
            Remove-CacheKeyIfPresent -Key "DomainState:$ComputerName"
        }

        # Preserve non-affected caches
        # Dacls and GpoState are never touched by scoped clearing
    }
    # If we reach here, we have performed the scoped clearing (or none was required).
    # Do not overwrite non-scoped caches here.
}
