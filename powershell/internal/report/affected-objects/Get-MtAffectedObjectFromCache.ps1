function Get-MtAffectedObjectFromCache {
    <#
    .SYNOPSIS
    Derives the affected objects from the request caches in the current Maester session.

    .DESCRIPTION
    Walks $__MtSession.GraphCache and $__MtSession.GitHubCache — both keyed by request URL —
    and parses each key into a normalized object record (System / AnchorKind / Type / Id / SourceUri).

    Graph URIs yield:
    - Instance records when a path segment is a GUID (e.g. users/{id}/authentication/methods)
      or a quoted key (e.g. authenticationMethodConfigurations('Fido2'))
    - Singleton records for tenant-level config resources (e.g. policies/authorizationPolicy)
    - Collection records for plain collection reads (e.g. users, servicePrincipals)

    GitHub cache keys ({ApiVersion}|{AbsoluteUri}) yield External records for the
    organization or repository addressed by the request.

    This is a run-level view (what data the run touched), not per-test attribution.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $guidPattern = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    # Graph resources that are always tenant-level singletons when read without a key
    $singletonPrefixes = @(
        'policies', 'settings', 'organization', 'admin', 'identityProtection/settings',
        'reports', 'directory/recommendations', 'networkAccess'
    )
    # Graph collections whose keyed reads address a directory object the rest of the inventory
    # already knows under a canonical EntraID type. Mapping them here means a check that both
    # reads users/{id} and renders a portal link produces one object, not two.
    # applications is deliberately absent: the cache keys it by object id while the portal links
    # parsed from markdown carry the app id, so the two would not merge anyway.
    $directoryTypes = @{
        users             = 'User'
        groups            = 'Group'
        devices           = 'Device'
        servicePrincipals = 'ServicePrincipal'
        directoryRoles    = 'DirectoryRole'
    }

    # Keyed reads below these collections address an object the checks also link to under a
    # canonical type, so the read merges with it instead of listing it a second time as a Graph path:
    # accessPackages/{id}/accessPackageResourceRoleScopes is that access package.
    $keyedObjectTypes = @{
        'identityGovernance/entitlementManagement/accessPackages'        = 'AccessPackage'
        'identityGovernance/entitlementManagement/accessPackageCatalogs' = 'AccessPackageCatalog'
    }

    # Action endpoints are verbs, not resources: they address no object worth inventorying.
    $actionSegments = @('$batch', 'runHuntingQuery', 'getMemberGroups', 'getMemberObjects', 'checkMemberGroups')

    $records = [System.Collections.Generic.List[object]]::new()

    if ($__MtSession.GraphCache) {
        foreach ($key in $__MtSession.GraphCache.Keys) {
            # POST cache keys append "_<json body>" (or a bare "_" when the body is empty). A plain
            # underscore is part of the path: guest UPNs look like john_contoso.com#EXT#@tenant.
            $uri = ($key -split '_(?=[\{\[]|$)', 2)[0]
            if ($uri -notmatch '^https://[^/]*graph[^/]*/(v1\.0|beta)/(.+)$') { continue }
            $path = $Matches[2]
            # Strip query string
            $path = ($path -split '\?', 2)[0].TrimEnd('/')
            if ([string]::IsNullOrEmpty($path)) { continue }

            $segments = $path -split '/'
            if ($segments[-1] -in $actionSegments) { continue }

            # A keyed read of a directory collection is the object itself, whatever sub-resource
            # follows: users/{id}/authentication/methods is still that user, not a fifth object.
            # The key may be a GUID or a UPN, and a UPN must be recognised or it lands in Type,
            # where the report's PII redaction never reaches it.
            if ($segments.Count -ge 2 -and $directoryTypes.ContainsKey($segments[0])) {
                # Cache keys are AbsoluteUri values, so a UPN arrives percent-encoded (#EXT# as %23EXT%23).
                $directoryKey = [uri]::UnescapeDataString($segments[1])
            } else {
                $directoryKey = $null
            }
            if ($directoryKey -and ($directoryKey -match $guidPattern -or $directoryKey.Contains('@'))) {
                $records.Add([PSCustomObject]@{
                        System            = 'EntraID'
                        AnchorKind        = 'Instance'
                        Type              = $directoryTypes[$segments[0]]
                        Id                = $directoryKey
                        DisplayName       = $null
                        UserPrincipalName = if ($segments[0] -eq 'users' -and $directoryKey.Contains('@')) { $directoryKey } else { $null }
                        PortalLink        = $null
                        SourceUri         = $uri
                        Source            = 'GraphCache'
                    })
                continue
            }

            $instanceId = $null
            $keyedPath = $null
            $keyName = $null
            $typeSegments = [System.Collections.Generic.List[string]]::new()
            foreach ($segment in $segments) {
                if ($segment -match $guidPattern) {
                    # First key wins: in a/{x}/b/{y} the object is the outer object, not the child.
                    if (-not $instanceId) {
                        $instanceId = $segment
                        $keyedPath = $typeSegments -join '/'
                    }
                } elseif ($segment -match "^(?<res>[^(]+)\((?:(?<keyName>\w+)=)?'(?<key>[^']+)'\)") {
                    # Covers key('x') and alternate keys such as applications(appId='x').
                    $typeSegments.Add($Matches.res)
                    if (-not $instanceId) {
                        $instanceId = $Matches.key
                        $keyedPath = $typeSegments -join '/'
                        $keyName = $Matches.keyName
                    }
                } else {
                    $typeSegments.Add($segment)
                }
            }
            $type = $typeSegments -join '/'

            # Map keyed reads onto the canonical object type. App registrations are keyed by appId
            # everywhere else (portal links use it), so only an appId alternate key maps to one.
            $canonicalType = $null
            if ($instanceId -and $keyedPath -and $keyedObjectTypes.ContainsKey($keyedPath)) {
                $canonicalType = $keyedObjectTypes[$keyedPath]
            } elseif ($instanceId -and $keyedPath -eq 'applications' -and $keyName -eq 'appId') {
                $canonicalType = 'AppRegistration'
            }
            if ($canonicalType) {
                $records.Add([PSCustomObject]@{
                        System            = 'EntraID'
                        AnchorKind        = 'Instance'
                        Type              = $canonicalType
                        Id                = $instanceId
                        DisplayName       = $null
                        UserPrincipalName = $null
                        PortalLink        = $null
                        SourceUri         = $uri
                        Source            = 'GraphCache'
                    })
                continue
            }

            if ($instanceId) {
                $anchorKind = 'Instance'
            } elseif ($singletonPrefixes | Where-Object { $type -eq $_ -or $type.StartsWith("$_/") } | Select-Object -First 1) {
                $anchorKind = 'Singleton'
            } else {
                $anchorKind = 'Collection'
            }

            $records.Add([PSCustomObject]@{
                    System      = 'MicrosoftGraph'
                    AnchorKind  = $anchorKind
                    Type        = $type
                    Id          = $instanceId
                    DisplayName = $null
                    PortalLink  = $null
                    SourceUri   = $uri
                    Source      = 'GraphCache'
                })
        }
    }

    if ($__MtSession.GitHubCache) {
        foreach ($key in $__MtSession.GitHubCache.Keys) {
            # Key format: {ApiVersion}|{AbsoluteUri}
            $uri = ($key -split '\|', 2)[-1]
            if ($uri -notmatch '^https://[^/]+/(.+)$') { continue }
            $path = (($Matches[1]) -split '\?', 2)[0].TrimEnd('/')
            $segments = $path -split '/'

            $type = $null
            $id = $null
            if ($segments.Count -ge 2 -and $segments[0] -eq 'orgs') {
                $type = 'GitHubOrganization'
                $id = $segments[1]
            } elseif ($segments.Count -ge 3 -and $segments[0] -eq 'repos') {
                $type = 'GitHubRepository'
                $id = "$($segments[1])/$($segments[2])"
            } else {
                $type = 'GitHubResource'
                $id = $path
            }

            $records.Add([PSCustomObject]@{
                    System      = 'GitHub'
                    AnchorKind  = 'External'
                    Type        = $type
                    Id          = $id
                    DisplayName = $id
                    PortalLink  = $null
                    SourceUri   = $uri
                    Source      = 'GitHubCache'
                })
        }
    }

    # Dedupe on System/Type/Id — the same resource is often read via several query variants
    $deduped = $records | Group-Object -Property { "$($_.System)|$($_.Type)|$($_.Id)" } | ForEach-Object { $_.Group[0] }
    return @($deduped)
}
