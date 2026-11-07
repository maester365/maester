function Test-MtAccessPackageDrift {
    <#
    .SYNOPSIS
    Checks that the access to governed resources of one scope comes from access package assignments.

    .DESCRIPTION
    Shared check of MT.1255 (groups that are not role-assignable), MT.1256 (role-assignable groups) and MT.1257
    (enterprise applications). Access package drift (Microsoft Entra ID Governance > Access Guardian, Microsoft Graph
    beta accessDriftSummary) compares the members of governed groups and the app role assignments of governed
    enterprise applications with the access package assignments that should grant them. It lists only resources
    with drift, so the resources of the entitlement management catalogs tell whether a resource of the scope is
    governed at all:

    - drift in the scope: the check fails when a resource has unauthorized or missing access (missing access only
      lists the resource for review when IncludeMissingAccess is $false) and lists the drifted resources;
    - no drift, and governed resources in the scope: the check passes;
    - no drift, and no governed resource in the scope (or the catalogs cannot be read): the check is skipped.

    Writes the result with Add-MtTestResultDetail and returns $true, $false, or $null when the check is skipped.

    .EXAMPLE
    Test-MtAccessPackageDrift -Scope RoleAssignableGroup

    Checks the drift of governed role-assignable groups.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The governed resources to check: groups that are not role-assignable, role-assignable groups, or enterprise applications.
        [Parameter(Mandatory)]
        [ValidateSet('Group', 'RoleAssignableGroup', 'Application')]
        [string] $Scope,

        # Also fail when an access package assignment is missing its expected group membership or app role assignment.
        # Set to $false to fail on unauthorized access only and list missing access for review.
        [bool] $IncludeMissingAccess = $true,

        # Object IDs of governed groups or applications whose drift is ignored.
        [string[]] $ExcludedResourceId,

        # Maximum number of resources listed in the result; the others are counted.
        [ValidateRange(1, 1000)]
        [int] $MaxResources = 50
    )

    $scopeInfo = switch ($Scope) {
        'Group' {
            @{ DriftType = 'group'; OriginSystem = 'AadGroup'; Kind = 'group that is not role-assignable'; Singular = 'governed group'; Plural = 'governed groups'; Heading = '👥 Groups'; Column = 'Group'
                Access = 'members'; Note = 'Role-assignable groups are checked by MT.1256.' }
        }
        'RoleAssignableGroup' {
            @{ DriftType = 'group'; OriginSystem = 'AadGroup'; Kind = 'role-assignable group'; Singular = 'governed role-assignable group'; Plural = 'governed role-assignable groups'; Heading = '🚨 Role-assignable groups'; Column = 'Group'
                Access = 'members'; Note = 'Members of role-assignable groups can be assigned Microsoft Entra roles, so access that bypasses the access package is privileged access.' }
        }
        'Application' {
            @{ DriftType = 'application'; OriginSystem = 'AadApplication'; Kind = 'enterprise application'; Singular = 'governed application'; Plural = 'governed applications'; Heading = '🧩 Applications'; Column = 'Application'
                Access = 'app role assignments'; Note = $null }
        }
    }
    $pluralize = {
        param([int] $Count, [string] $Singular, [string] $Plural)
        "$Count $(if ($Count -eq 1) { $Singular } else { $Plural })"
    }
    $excluded = [System.Collections.Generic.HashSet[string]]::new([string[]]@($ExcludedResourceId | Where-Object { $_ }), [System.StringComparer]::OrdinalIgnoreCase)

    # The drift report lists only resources with drift; $expand=details adds up to five drift records each. The
    # request is the same for the group checks, so the second one is answered from the cache.
    $summaries = [System.Collections.Generic.List[object]]::new()
    try {
        $driftSplat = @{
            ApiVersion      = 'beta'
            RelativeUri     = 'identityGovernance/insights/accessDriftSummary'
            Filter          = "resource/type eq '$($scopeInfo.DriftType)' and driftSource eq 'entra'"
            QueryParameters = @{ '$expand' = 'details'; '$top' = '100' }
            ErrorAction     = 'Stop'
        }
        foreach ($summary in @(Invoke-MtGraphRequest @driftSplat)) {
            if ($null -ne $summary -and $summary.resource.identifier -and -not $excluded.Contains("$($summary.resource.identifier)")) {
                $summaries.Add($summary)
            }
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($statusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        if ($statusCode -in @(400, 404)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The access package drift report could not be read from Microsoft Graph ($statusCode). The report is in preview and may not be available in this tenant yet."
            return $null
        }
        throw
    }

    # The governed resources of the scope: the groups or applications that are resources of an entitlement
    # management catalog. They tell a resource without drift from a scope with nothing to check.
    $governedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $catalogError = $null
    try {
        $catalogs = @(Invoke-MtGraphRequest -RelativeUri 'identityGovernance/entitlementManagement/catalogs' -ApiVersion v1.0 -Select 'id' -ErrorAction Stop)
        foreach ($catalog in @($catalogs | Where-Object { $_.id })) {
            $catalogResources = @(Invoke-MtGraphRequest -RelativeUri "identityGovernance/entitlementManagement/catalogs/$($catalog.id)/resources" -ApiVersion v1.0 `
                    -Select 'id', 'originId', 'originSystem' -ErrorAction Stop)
            foreach ($catalogResource in $catalogResources) {
                if ($catalogResource.originSystem -eq $scopeInfo.OriginSystem -and $catalogResource.originId -and -not $excluded.Contains("$($catalogResource.originId)")) {
                    $null = $governedIds.Add("$($catalogResource.originId)")
                }
            }
        }
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
        $catalogError = "$(if ($statusCode) { "HTTP $($statusCode): " })$(("$($_.Exception.Message)" -split '\r?\n')[0])"
        Write-Verbose "Could not read the resources of the entitlement management catalogs: $catalogError"
    }

    # Role-assignable groups can hold Microsoft Entra roles: they are checked on their own (MT.1256), so the groups
    # of the report and of the catalogs are split by isAssignableToRole.
    if ($scopeInfo.DriftType -eq 'group') {
        $groupIds = @(@($summaries | ForEach-Object { "$($_.resource.identifier)" }) + @($governedIds) | Where-Object { $_ })
        $groupIds = @([System.Collections.Generic.HashSet[string]]::new([string[]]$groupIds, [System.StringComparer]::OrdinalIgnoreCase))
        $roleAssignableIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($groupIds.Count -gt 0) {
            foreach ($groupId in $groupIds) {
                $parsedGroupId = [guid]::Empty
                if (-not [guid]::TryParse($groupId, [ref]$parsedGroupId)) {
                    throw "Could not classify governed group '$groupId': the resource identifier is not a group object ID."
                }
            }
            # The Graph helper omits batch 404 responses. Verify missing groups individually before treating them
            # as deleted: an incomplete batch response is not evidence that a group cannot hold a role.
            try {
                $groups = @(Invoke-MtGraphRequest -RelativeUri 'groups' -UniqueId $groupIds -Select 'id', 'isAssignableToRole' -ErrorAction Stop)
            } catch {
                # A single group is requested without a batch, so a deleted group throws instead of returning an error body.
                $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
                if ($groupIds.Count -ne 1 -or $statusCode -ne 404) { throw }
                $groups = @([pscustomobject]@{ error = [pscustomobject]@{ code = 'Request_ResourceNotFound' } })
            }
            $errorResponses = @($groups | Where-Object { $_.error })
            $otherErrors = @($errorResponses | Where-Object { "$($_.error.code)" -ne 'Request_ResourceNotFound' })
            if ($otherErrors.Count -gt 0) {
                $codes = @($otherErrors | ForEach-Object { "$($_.error.code): $(("$($_.error.message)" -split '\r?\n')[0])" } | Select-Object -Unique) -join '; '
                throw "Could not classify governed groups: Microsoft Graph returned $($otherErrors.Count) error(s) for $($groupIds.Count) groups ($codes)."
            }
            $resolved = @($groups | Where-Object { -not $_.error })
            if (@($resolved | Where-Object { -not $_.id -or "$($_.id)" -notin $groupIds }).Count -gt 0) {
                throw 'Could not classify governed groups: Microsoft Graph returned a group response without a requested group ID.'
            }
            $missingIds = @($groupIds | Where-Object { $groupId = $_; -not ($resolved | Where-Object { "$($_.id)" -eq $groupId }) })
            $deletedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            if ($errorResponses.Count -gt 0) {
                if ($missingIds.Count -ne $errorResponses.Count) {
                    throw "Could not classify governed groups: Microsoft Graph returned $($errorResponses.Count) not-found responses for $($missingIds.Count) unresolved of $($groupIds.Count) groups."
                }
                foreach ($missingId in $missingIds) { $null = $deletedIds.Add($missingId) }
            } else {
                foreach ($missingId in $missingIds) {
                    Write-Verbose "The group batch did not return '$missingId'; verifying it with an individual request."
                    try {
                        $retriedGroups = @(Invoke-MtGraphRequest -RelativeUri 'groups' -UniqueId $missingId -Select 'id', 'isAssignableToRole' -ErrorAction Stop)
                    } catch {
                        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
                        if ($statusCode -ne 404) { throw }
                        $null = $deletedIds.Add($missingId)
                        continue
                    }
                    if ($retriedGroups.Count -ne 1 -or "$($retriedGroups[0].id)" -ne $missingId) {
                        throw "Could not classify governed group '$missingId': the individual request did not return exactly the requested group."
                    }
                    $groups += $retriedGroups
                }
            }
            foreach ($deletedId in $deletedIds) { Write-Verbose "Governed group $deletedId no longer exists; it is not role-assignable." }
            foreach ($groupId in $groupIds) {
                if ($deletedIds.Contains($groupId)) { continue }
                $resolvedGroups = @($groups | Where-Object { "$($_.id)" -eq $groupId })
                if ($resolvedGroups.Count -ne 1) {
                    throw "Could not classify governed group '$groupId': Microsoft Graph did not return the group exactly once."
                }
                # Microsoft Graph returns null for groups created without the property: they are not role-assignable.
                $isAssignableToRole = $resolvedGroups[0].isAssignableToRole
                if ($null -ne $isAssignableToRole -and $isAssignableToRole -isnot [bool]) {
                    throw "Could not classify governed group '$groupId': isAssignableToRole is not a boolean."
                }
                if ($isAssignableToRole -eq $true) { $null = $roleAssignableIds.Add($groupId) }
            }
        }
        $wantRoleAssignable = $Scope -eq 'RoleAssignableGroup'
        $summaries = @($summaries | Where-Object { $roleAssignableIds.Contains("$($_.resource.identifier)") -eq $wantRoleAssignable })
        $governedIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($governedIds | Where-Object { $roleAssignableIds.Contains($_) -eq $wantRoleAssignable }), [System.StringComparer]::OrdinalIgnoreCase)
    }
    $drifted = @($summaries)

    if ($drifted.Count -eq 0) {
        if ($catalogError) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Access package drift reports no drift for $($scopeInfo.Plural), but the resources of the entitlement management catalogs could not be read ($catalogError), so it is not known whether any of them are governed."
            return $null
        }
        if ($governedIds.Count -eq 0) {
            $exclusionText = if ($excluded.Count -gt 0) { ' (after ExcludedResourceId)' } else { '' }
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No $($scopeInfo.Kind) is a resource of an entitlement management catalog$exclusionText, so there is no access package drift to check."
            return $null
        }
        Add-MtTestResultDetail -Result "Well done. Access package drift reports no unauthorized or missing access on the $(& $pluralize $governedIds.Count $scopeInfo.Singular $scopeInfo.Plural)."
        return $true
    }

    # The report has one summary per resource and catalog: list a resource in several catalogs once. Its counts
    # are the highest of its catalogs, because the same identities usually drift in each of them.
    $resources = @($drifted | Group-Object -Property { "$($_.resource.identifier)" } | ForEach-Object {
            $catalogSummaries = @($_.Group | Sort-Object -Property { $_.resource.catalogName })
            [pscustomobject]@{
                Type         = $catalogSummaries[0].resource.type
                Name         = $catalogSummaries[0].resource.displayName
                Summaries    = $catalogSummaries
                Unauthorized = [int]($catalogSummaries | ForEach-Object { [int]$_.driftCounts.unauthorized } | Measure-Object -Maximum).Maximum
                Missing      = [int]($catalogSummaries | ForEach-Object { [int]$_.driftCounts.missing } | Measure-Object -Maximum).Maximum
            }
        } | Sort-Object -Property @{ Expression = 'Unauthorized'; Descending = $true }, @{ Expression = 'Name' })
    $unauthorizedCount = [int]($resources | Measure-Object -Property Unauthorized -Sum).Sum
    $missingCount = [int]($resources | Measure-Object -Property Missing -Sum).Sum
    $testResult = @($resources | Where-Object { $_.Unauthorized -gt 0 -or ($IncludeMissingAccess -and $_.Missing -gt 0) }).Count -eq 0

    $governedText = if (-not $catalogError -and $governedIds.Count -ge $resources.Count) { " of $($governedIds.Count)" } else { '' }
    if ($testResult) {
        $testResultMarkdown = "Well done. No $($scopeInfo.Singular) has unauthorized $($scopeInfo.Access)."
        # Missing access only passes when IncludeMissingAccess is $false: it is listed for review.
        if ($missingCount -gt 0) {
            $testResultMarkdown += " $missingCount access package $(if ($missingCount -eq 1) { 'assignment is' } else { 'assignments are' }) missing the expected access on $($resources.Count)$governedText $(if ($resources.Count -eq 1) { $scopeInfo.Singular } else { $scopeInfo.Plural }); review them below."
        }
    } else {
        $testResultMarkdown = "Access package drift reports **$unauthorizedCount** unauthorized and **$missingCount** missing access on $($resources.Count)$governedText $(if ($resources.Count -eq 1) { $scopeInfo.Singular } else { $scopeInfo.Plural })."
        if ($unauthorizedCount -gt 0) {
            $testResultMarkdown += " Remove $($scopeInfo.Access) that were granted outside an access package, or move them into an access package assignment."
        }
        if ($IncludeMissingAccess -and $missingCount -gt 0) {
            $testResultMarkdown += " Reprocess the access package assignments that are missing their expected access."
        }
    }
    if ($scopeInfo.Note) { $testResultMarkdown += " $($scopeInfo.Note)" }

    # The report is refreshed about once a day; show when its data was created.
    $createdTimes = @($drifted | ForEach-Object {
            $created = [datetimeoffset]::MinValue
            if ($_.createdDateTime -and [datetimeoffset]::TryParse("$($_.createdDateTime)", [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$created)) { $created }
        })
    if ($createdTimes.Count -gt 0) {
        $dataAsOf = ($createdTimes | Sort-Object -Descending | Select-Object -First 1).UtcDateTime.ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
        $testResultMarkdown += "`n`n_Drift data as of $dataAsOf UTC._"
    }
    if ($catalogError) {
        $testResultMarkdown += "`n`n❔ The resources of the entitlement management catalogs could not be read ($($catalogError -replace '\|', '\|')), so only the resources with drift are counted."
    }

    # Link every object to its admin portal page: the Affected objects page of the report picks them up
    # from these deep links (see powershell/internal/report/affected-objects).
    $entraPortal = $__MtSession.AdminPortalUrl.Entra
    # The kinds of object in the drift report, mapped to the shared portal link templates.
    $sharedLinkTemplates = (Get-MtPortalLinkTemplate).LinkTemplates
    $linkTemplates = @{
        group            = $sharedLinkTemplates.Groups
        application      = $sharedLinkTemplates.ServicePrincipals
        servicePrincipal = $sharedLinkTemplates.ServicePrincipals
        user             = $sharedLinkTemplates.Users
        catalog          = $sharedLinkTemplates.AccessPackageCatalogs
        accessPackage    = $sharedLinkTemplates.AccessPackages
    }
    $formatLink = {
        param([string] $Kind, [string] $Id, [string] $Name)
        $text = Get-MtSafeMarkdown $(if ($Name) { $Name } elseif ($Id) { $Id } else { 'Unknown' })
        $parsedGuid = [guid]::Empty
        $isGuid = [guid]::TryParse($Id, [ref]$parsedGuid)
        if ($entraPortal -and $isGuid -and $linkTemplates.ContainsKey($Kind)) {
            return "[$text]($($linkTemplates[$Kind] -f $Id))"
        }
        return $text
    }
    # A catalog of a drifted resource, linked to the drift details of the resource in that catalog
    # (Access Guardian > Reports > Access Drift). Falls back to the catalog's own page when no summary id is known.
    $formatCatalogDriftLink = {
        param($Summary)
        if (-not $entraPortal -or -not $Summary.id) {
            return "📚 $(& $formatLink 'catalog' $Summary.resource.catalogIdentifier $Summary.resource.catalogName)"
        }
        # EscapeDataString leaves ( ) ! * ' unencoded; encode them too so they cannot end the markdown link.
        $encode = {
            param([string] $Value)
            [uri]::EscapeDataString($Value) -replace '\(', '%28' -replace '\)', '%29' -replace '!', '%21' -replace '\*', '%2A' -replace "'", '%27'
        }
        $segments = @(
            "summaryId/$(& $encode $Summary.id)"
            "resourceId/$(& $encode $Summary.resource.identifier)"
            "catalogIdentifier/$(& $encode $Summary.resource.catalogIdentifier)"
            "catalogName/$(& $encode $Summary.resource.catalogName)"
            "resourceType/$(& $encode $Summary.resource.type)"
            "resourceName/$(& $encode $Summary.resource.displayName)"
            "driftTotal~/$([int]$Summary.driftCounts.total)"
            "driftUnauthorized~/$([int]$Summary.driftCounts.unauthorized)"
            "driftMissing~/$([int]$Summary.driftCounts.missing)"
        )
        $catalogName = if ($Summary.resource.catalogName) { $Summary.resource.catalogName } elseif ($Summary.resource.catalogIdentifier) { $Summary.resource.catalogIdentifier } else { 'Unknown catalog' }
        $title = "View access drift of $($Summary.resource.displayName) in catalog $catalogName"
        # The title sits in a quoted link title inside a table cell: drop quotes and backslashes, escape pipes.
        $title = $title -replace '["\\]', '' -replace '\r?\n', ' ' -replace '\|', '\|'
        return "📚 [$(Get-MtSafeMarkdown $catalogName)]($($entraPortal)#view/Microsoft_Azure_ELMAdmin/ReconReviewAccessDriftBlade.ReactView/$($segments -join '/') `"$title`")"
    }

    # The kind and name of each identity in the examples. The drift report documents only user and group, but service
    # principals and agent identities appear too, named only by their app ID, so the object type and display name
    # are read from the directory in one batch.
    $identityKinds = @{}
    $identityNames = @{}
    $identityIds = @($resources | ForEach-Object { $_.Summaries } | ForEach-Object { $_.details } | Where-Object { $null -ne $_ } |
            ForEach-Object { $_.identities } | Where-Object { $null -ne $_ -and $_.identityType -ne 'group' -and $_.identifier } |
            ForEach-Object { "$($_.identifier)" } | Where-Object { $parsedIdentityId = [guid]::Empty; [guid]::TryParse($_, [ref]$parsedIdentityId) } | Select-Object -Unique)
    if ($identityIds.Count -gt 0) {
        try {
            foreach ($directoryObject in @(Invoke-MtGraphRequest -RelativeUri 'directoryObjects' -UniqueId $identityIds -Select 'id', 'displayName' -ErrorAction Stop)) {
                if (-not $directoryObject.id) { continue }
                if ($directoryObject.'@odata.type') { $identityKinds["$($directoryObject.id)"] = "$($directoryObject.'@odata.type')" }
                if ($directoryObject.displayName) { $identityNames["$($directoryObject.id)"] = "$($directoryObject.displayName)" }
            }
        } catch {
            Write-Verbose "Could not read the object type of the drifted identities: $($_.Exception.Message)"
        }
    }
    $resolveIdentityKind = {
        param($Identity)
        $type = if ($identityKinds.ContainsKey("$($Identity.identifier)")) { $identityKinds["$($Identity.identifier)"] } else { "$($Identity.identityType)" }
        switch -Regex ($type) {
            'agent' { 'agent'; break }
            'servicePrincipal|application' { 'servicePrincipal'; break }
            'group' { 'group'; break }
            default { 'user' }
        }
    }
    # Identities of the examples: users, groups, service principals and agent identities are marked, and a guest
    # shows the address it was invited with instead of its user principal name (alias_domain#EXT#@tenant).
    $formatIdentity = {
        param($Identity)
        $kind = & $resolveIdentityKind $Identity
        $name = if ($Identity.principalName) { $Identity.principalName } else { $Identity.displayName }
        # A service principal or agent identity is named by its app ID in the report: show its display name instead,
        # as for any identity the report names only by an ID.
        $directoryName = $identityNames["$($Identity.identifier)"]
        $parsedName = [guid]::Empty
        if ($directoryName -and ($kind -in @('servicePrincipal', 'agent') -or -not $name -or [guid]::TryParse("$name", [ref]$parsedName))) {
            $name = $directoryName
        }
        $guestSuffix = ''
        if ($kind -eq 'user' -and "$name" -match '^(?<alias>.+)_(?<domain>[^_@#]+)#EXT#@') {
            $name = "$($Matches.alias)@$($Matches.domain)"
            $guestSuffix = ' (guest)'
        }
        $icon = switch ($kind) { 'group' { '👥' } 'servicePrincipal' { '🧩' } 'agent' { '🤖' } default { '👤' } }
        $linkKind = switch ($kind) { 'group' { 'group' } 'servicePrincipal' { 'servicePrincipal' } 'agent' { 'servicePrincipal' } default { 'user' } }
        "$icon $(& $formatLink $linkKind $Identity.identifier $name)$guestSuffix"
    }
    # Examples of one resource across its catalogs, grouped by drift type. The report returns up to five drift
    # records per summary, so "+N more" points to the drift details for the rest.
    $formatExamples = {
        param($Resource)
        $lines = foreach ($driftType in @('unauthorized', 'missing')) {
            $total = if ($driftType -eq 'unauthorized') { $Resource.Unauthorized } else { $Resource.Missing }
            if ($total -eq 0) { continue }
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $items = foreach ($detail in @($Resource.Summaries | ForEach-Object { $_.details } | Where-Object { $null -ne $_ -and $_.driftType -eq $driftType })) {
                $identities = @($detail.identities | Where-Object { $null -ne $_ -and $seen.Add("$($_.identifier)|$($_.principalName)") } | ForEach-Object { & $formatIdentity $_ })
                if ($identities.Count -eq 0) { continue }
                $text = $identities -join ', '
                if ($detail.accessPackage.identifier -or $detail.accessPackage.displayName) {
                    $text += " (access package: $(& $formatLink 'accessPackage' $detail.accessPackage.identifier $detail.accessPackage.displayName))"
                }
                $text
            }
            $label = if ($driftType -eq 'unauthorized') { '🚫 Unauthorized' } else { '⚠️ Missing' }
            $more = $total - $seen.Count
            "$($label): $(if (@($items).Count -gt 0) { @($items) -join ', ' } else { 'no examples returned' })$(if ($more -gt 0) { " · **+$more more**" })"
        }
        # Table cells cannot hold line breaks, so the drift types are separated by an escaped pipe.
        if (@($lines).Count -gt 0) { @($lines) -join ' \| ' } else { 'None returned' }
    }

    # Missing access is only a column when a resource has some, or when it fails the check.
    $showMissing = $IncludeMissingAccess -or @($resources | Where-Object { $_.Missing -gt 0 }).Count -gt 0
    $testResultMarkdown += "`n`n#### $($scopeInfo.Heading) ($($resources.Count))`n`n"
    if ($showMissing) {
        $testResultMarkdown += "| $($scopeInfo.Column) | Drift in Catalog(s) | Unauthorized | Missing | Examples |`n| --- | --- | ---: | ---: | --- |`n"
    } else {
        $testResultMarkdown += "| $($scopeInfo.Column) | Drift in Catalog(s) | Unauthorized | Examples |`n| --- | --- | ---: | --- |`n"
    }
    foreach ($resource in @($resources | Select-Object -First $MaxResources)) {
        $first = $resource.Summaries[0]
        $resourceLink = & $formatLink $first.resource.type $first.resource.identifier $first.resource.displayName
        # Each catalog of the resource links to the drift details of the resource in that catalog.
        # Catalogs are separated by an escaped pipe; counts only when they differ.
        $countsDiffer = @($resource.Summaries | ForEach-Object { "$([int]$_.driftCounts.unauthorized)|$([int]$_.driftCounts.missing)" } | Select-Object -Unique).Count -gt 1
        $catalogText = @($resource.Summaries | ForEach-Object {
                $line = & $formatCatalogDriftLink $_
                if ($countsDiffer) {
                    $line += " ($([int]$_.driftCounts.unauthorized) unauthorized$(if ($showMissing) { ", $([int]$_.driftCounts.missing) missing" }))"
                }
                $line
            }) -join ' \| '
        $examplesText = & $formatExamples $resource
        if ($showMissing) {
            $testResultMarkdown += "| $resourceLink | $catalogText | $($resource.Unauthorized) | $($resource.Missing) | $examplesText |`n"
        } else {
            $testResultMarkdown += "| $resourceLink | $catalogText | $($resource.Unauthorized) | $examplesText |`n"
        }
    }
    $hiddenCount = $resources.Count - $MaxResources
    if ($hiddenCount -gt 0) {
        $testResultMarkdown += "`n… and $(& $pluralize $hiddenCount $scopeInfo.Singular $scopeInfo.Plural) with less drift. See all of them in the Microsoft Entra admin center under **ID Governance** > **Access Guardian** > **Reports** > **Access Drift**.`n"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
