function Get-MtAffectedObject {
    <#
    .SYNOPSIS
    Builds a consolidated affected objects of all objects involved in a Maester test run.

    .DESCRIPTION
    Combines three sources into one normalized inventory:
    1. Structured RelatedObjects captured by Add-MtTestResultDetail (per-test attribution, strongest signal)
    2. Portal deep links parsed from result markdown (covers ad-hoc $portalLink sites and old reports)
    3. Session request caches (run-level view of every Graph/GitHub resource the run touched)

    Records are deduplicated on System/Type/Id; per-test attribution is aggregated
    into a Tests array so each object shows which checks reference it.

    .EXAMPLE
    $results = Invoke-Maester -PassThru
    Get-MtAffectedObject -MaesterResults $results
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # The Maester results object (as produced by ConvertTo-MtMaesterResult / Invoke-Maester -PassThru,
        # or re-hydrated from a TestResults json file). Optional: without it only the session caches are used.
        [Parameter(Mandatory = $false)]
        [psobject] $MaesterResults,

        # Skip the session-cache source (e.g. when analyzing a report file offline).
        [Parameter(Mandatory = $false)]
        [switch] $ExcludeSessionCache
    )

    $records = [System.Collections.Generic.List[object]]::new()

    if ($MaesterResults -and $MaesterResults.Tests) {
        foreach ($test in $MaesterResults.Tests) {
            $detail = $test.ResultDetail
            if (-not $detail) { continue }

            # Source 1: structured records captured before markdown rendering
            foreach ($related in @(Get-ObjectProperty $detail 'RelatedObjects')) {
                if ($null -eq $related) { continue }
                $records.Add([PSCustomObject]@{
                        System            = $related.System
                        AnchorKind        = $related.AnchorKind
                        Type              = $related.Type
                        Id                = $related.Id
                        DisplayName       = $related.DisplayName
                        UserPrincipalName = Get-ObjectProperty $related 'UserPrincipalName'
                        PortalLink        = $related.PortalLink
                        TestId            = $test.Id
                        Source            = $related.Source
                    })
            }

            # Source 2: portal deep links in the rendered markdown
            $markdown = Get-ObjectProperty $detail 'TestResult'
            if (-not [string]::IsNullOrWhiteSpace($markdown)) {
                foreach ($parsed in @(Get-MtAffectedObjectFromMarkdown -Markdown $markdown -TestId $test.Id)) {
                    $records.Add($parsed)
                }
            }
        }
    }

    # Source 3: run-level cache view
    if (-not $ExcludeSessionCache) {
        foreach ($cached in @(Get-MtAffectedObjectFromCache)) {
            $records.Add(($cached | Select-Object *, @{n = 'TestId'; e = { $null } }))
        }
    }

    # Some sources only know a user by UPN (users/{upn} reads, [upn]() links in recommendation
    # results). Key those records by the user's object id when the run saw it, so each user is one
    # object instead of one per identifier.
    $userIdByUpn = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in $records) {
        $userPrincipalName = Get-ObjectProperty $record 'UserPrincipalName'
        if ($record.Type -eq 'User' -and $userPrincipalName -and $record.Id -and -not ([string]$record.Id).Contains('@')) {
            $userIdByUpn[[string]$userPrincipalName] = [string]$record.Id
        }
    }
    if (-not $ExcludeSessionCache -and $__MtSession.GraphCache) {
        foreach ($response in @($__MtSession.GraphCache.Values)) {
            if ($null -eq $response -or $response -is [string]) { continue }
            foreach ($item in @($response) + @($response.value)) {
                if ($null -eq $item -or $item -is [string]) { continue }
                $userPrincipalName = [string](Get-ObjectProperty $item 'userPrincipalName')
                $id = [string](Get-ObjectProperty $item 'id')
                if ($userPrincipalName -and $id -and -not $userIdByUpn.ContainsKey($userPrincipalName)) {
                    $userIdByUpn[$userPrincipalName] = $id
                }
            }
        }
    }
    $userLinkTemplate = (Get-MtPortalLinkTemplate).LinkTemplates.Users
    foreach ($record in $records) {
        $upnKey = [string]$record.Id
        $userId = $null
        if ($record.Type -eq 'User' -and $upnKey.Contains('@') -and $userIdByUpn.TryGetValue($upnKey, [ref] $userId)) {
            $record.Id = $userId
            if (-not $record.PortalLink -and $userLinkTemplate) { $record.PortalLink = $userLinkTemplate -f $userId }
        }
    }

    # Consolidate: one record per System/Type/Id with aggregated test attribution.
    # Structured GraphObjects records win over markdown/cache records for the same object.
    # Unknown sources rank last so a record with a missing Source never outranks a structured one.
    $sourceRank = @{ GraphObjects = 0; Markdown = 1; GraphCache = 2; GitHubCache = 2 }
    # Objects passed without an id fall back to their UPN or name, otherwise distinct users would
    # merge into one object and all but the first would escape redaction.
    $identityOf = {
        param($record)
        if ($record.Id) { return [string]$record.Id }
        $userPrincipalName = Get-ObjectProperty $record 'UserPrincipalName'
        # Bare UPN: the same key a users/{upn} cache read and the signed-in account produce.
        if ($userPrincipalName) { return [string]$userPrincipalName }
        if ($record.DisplayName) { return "name:$($record.DisplayName)" }
        return ''
    }
    $inventory = $records | Group-Object -Property { "$($_.System)|$($_.Type)|$(& $identityOf $_)" } | ForEach-Object {
        $best = $_.Group | Sort-Object {
            $rank = $sourceRank[[string]$_.Source]
            if ($null -eq $rank) { [int]::MaxValue } else { $rank }
        } | Select-Object -First 1
        $uniqueId = Get-MtAffectedObjectUniqueId -System $best.System -Type $best.Type -Id (& $identityOf $best)
        [PSCustomObject]@{
            System            = $best.System
            AnchorKind        = $best.AnchorKind
            Type              = $best.Type
            Id                = $best.Id
            UniqueId          = $uniqueId
            # Prefer a real name over a UPN that only stood in for one ([upn]() links, users/{upn} reads).
            DisplayName       = (@($_.Group.DisplayName | Where-Object { $_ }) | Sort-Object { ([string]$_).Contains('@') } | Select-Object -First 1)
            UserPrincipalName = ($_.Group | ForEach-Object { Get-ObjectProperty $_ 'UserPrincipalName' } | Where-Object { $_ } | Select-Object -First 1)
            PortalLink        = ($_.Group.PortalLink | Where-Object { $_ } | Select-Object -First 1)
            Tests             = @($_.Group.TestId | Where-Object { $_ } | Select-Object -Unique)
            Sources           = @($_.Group.Source | Select-Object -Unique)
        }
    }

    # Assign first: Select-MtAffectedObjectByType returns a comma-forced array, which a direct pipe into
    # Sort-Object would hand over as one object instead of enumerating it.
    $filtered = Select-MtAffectedObjectByType -Objects $inventory

    return @($filtered | Sort-Object System, Type, DisplayName)
}
