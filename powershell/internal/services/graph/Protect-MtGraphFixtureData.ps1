function Protect-MtGraphFixtureData {
    <#
    .SYNOPSIS
    Internal: Replaces tenant data in a recorded Graph response, request uri or body with stable fake values.

    .DESCRIPTION
    Graph recording (Enable-MtGraphFixture -Mode Record) runs every response through this before it is written, unless
    the recording was started with -NoSanitize. It replaces:

      - GUIDs (tenant ID, object IDs), except the well-known ones Maester compares with
        (Get-MtGraphFixtureWellKnownId and -PreserveValue): fa4efa4e-xxxx-xxxx-xxxx-xxxxxxxxxxxx
      - email addresses and user principal names: user-<hash>@<fake domain>, and guest-<hash>#EXT#@<fake domain> for
        guest UPNs, so a check that looks for #EXT# still finds it
      - the tenant's domain names, wherever they appear in a string: fake<hash>.example, or
        fake<hash>.onmicrosoft.com (and .sharepoint.com and the other Microsoft suffixes) so the suffix a check
        looks for is kept
      - the displayName of directory objects that have a tenant-specific id (users, groups, applications, policies),
        but not of built-in objects such as directory roles: <type>-<hash>
      - personal fields of users (given name, surname, phone numbers, address, on-premises names and SIDs): redacted-<hash>

    Each fake value is an HMAC of the real one with the fixture set's salt, so the same real value always gets the
    same fake value and the relationships between objects survive: a group member's id is the id of the user.
    Fake values are recognisable, and are never replaced again.

    What it does not catch is listed in the documentation (website/docs/writing-tests/graph-fixtures.md): free text,
    such as descriptions, that names people or the company; IP addresses; certificates and other binary values.

    .EXAMPLE
    Protect-MtGraphFixtureData -Node $responseNode -State $__MtSession.GraphFixture

    Replaces the tenant data in a parsed response, in place.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Node')]
    [OutputType([string])]
    param(
        # A parsed JSON response or body. It is changed in place.
        [Parameter(Mandatory, ParameterSetName = 'Node')]
        [AllowNull()]
        [System.Text.Json.Nodes.JsonNode] $Node,

        # A text, such as a request uri. The protected text is returned.
        [Parameter(Mandatory, ParameterSetName = 'Text')]
        [AllowEmptyString()]
        [string] $Text,

        # The text is a request uri: a display name in quotes in a filter is replaced too.
        [Parameter(ParameterSetName = 'Text')]
        [switch] $Uri,

        # The record state: Salt, WellKnownIds, Domains and DisplayNames.
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $State
    )

    $salt = [string]$State.Salt
    $wellKnown = $State.WellKnownIds
    $domains = $State.Domains

    $fakeHash = { param($kind, $value) Get-MtGraphFixtureHash -Text ('{0}:{1}' -f $kind, $value.ToLowerInvariant()) -Salt $salt }

    $guidPattern = '(?<![0-9A-Fa-f])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?![0-9A-Fa-f])'
    $emailPattern = "(?<![A-Za-z0-9._%+'#-])(?<local>[A-Za-z0-9._%+'#-]+)@(?<domain>[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)"
    # Microsoft suffixes that a check may look for; only the tenant's own label in front of them is replaced.
    $keptSuffixes = 'mail.onmicrosoft.com', 'onmicrosoft.com', 'onmicrosoft.us', 'onmicrosoft.de', 'partner.onmschina.cn', 'sharepoint.com', 'sharepoint.us', 'sharepoint.cn', 'onedrive.com'
    $suffixPattern = '(?<![A-Za-z0-9-])[A-Za-z0-9-]+\.(?:' + (($keptSuffixes | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?![A-Za-z0-9-])'
    # Domains that are never the tenant's: an address at one of them keeps its domain.
    $serviceDomains = 'microsoft.com', 'microsoftonline.com', 'windows.net', 'azure.com', 'azure.net', 'office.com', 'office365.com', 'office.net', 'live.com', 'microsoft.us', 'chinacloudapi.cn', 'example', 'example.com'

    $isFakeDomain = { param($domain) $domain -match '(^|\.)fake[0-9a-f]{6}\.' -or $domain -match '\.example$' }
    $isServiceDomain = {
        param($domain)
        $lower = $domain.ToLowerInvariant()
        foreach ($service in $serviceDomains) { if ($lower -eq $service -or $lower.EndsWith(".$service")) { return $true } }
        foreach ($suffix in $keptSuffixes) { if ($lower -eq $suffix) { return $true } }
        return $false
    }

    $fakeGuid = {
        param($guid)
        if ($guid -match '^fa4efa4e-' -or ($wellKnown -and $wellKnown.Contains($guid))) { return $guid }
        $h = & $fakeHash 'guid' $guid
        $fake = 'fa4efa4e-{0}-{1}-{2}-{3}' -f $h.Substring(0, 4), $h.Substring(4, 4), $h.Substring(8, 4), $h.Substring(12, 12)
        if ($guid -cmatch '[A-F]' -and $guid -cnotmatch '[a-f]') { $fake = $fake.ToUpperInvariant() }
        return $fake
    }

    $fakeDomain = {
        param($domain)
        if (& $isFakeDomain $domain) { return $domain }
        $lower = $domain.ToLowerInvariant()
        foreach ($suffix in $keptSuffixes) {
            if ($lower.EndsWith(".$suffix")) {
                $label = $lower.Substring(0, $lower.Length - $suffix.Length - 1)
                return 'fake{0}.{1}' -f (& $fakeHash 'domain' $label).Substring(0, 6), $suffix
            }
        }
        return 'fake{0}.example' -f (& $fakeHash 'domain' $lower).Substring(0, 6)
    }

    $addDomain = {
        param($domain)
        if ($null -eq $domains -or [string]::IsNullOrWhiteSpace($domain)) { return }
        $domain = $domain.Trim().TrimEnd('.')
        if ($domain -notmatch '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' -or (& $isFakeDomain $domain) -or (& $isServiceDomain $domain)) { return }
        $null = $domains.Add($domain.ToLowerInvariant())
    }

    $protectText = {
        param([string] $value, [bool] $isUri)
        if ([string]::IsNullOrEmpty($value)) { return $value }

        # Addresses first, so that their domains are known to the domain pass below.
        $value = [regex]::Replace($value, $emailPattern, {
                param($m)
                $local = $m.Groups['local'].Value
                $domain = $m.Groups['domain'].Value
                if ((& $isFakeDomain $domain) -and $local -match '^(user|guest)-[0-9a-f]{8}') { return $m.Value }
                & $addDomain $domain
                $newDomain = if (& $isServiceDomain $domain) { $domain } else { & $fakeDomain $domain }
                $newLocal = if ($local -match '#EXT#') { 'guest-{0}#EXT#' -f (& $fakeHash 'local' $local).Substring(0, 8) } else { 'user-{0}' -f (& $fakeHash 'local' "$local@$domain").Substring(0, 8) }
                return "$newLocal@$newDomain"
            })

        $value = [regex]::Replace($value, $guidPattern, { param($m) & $fakeGuid $m.Value })
        $value = [regex]::Replace($value, $suffixPattern, { param($m) if ($m.Value -match '^fake[0-9a-f]{6}\.') { $m.Value } else { & $fakeDomain $m.Value } }, 'IgnoreCase')

        if ($domains -and $domains.Count -gt 0) {
            if ($State.DomainPatternCount -ne $domains.Count) {
                $alternatives = @($domains | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) })
                $State.DomainPattern = [regex]::new('(?<![A-Za-z0-9-])(?:' + ($alternatives -join '|') + ')(?![A-Za-z0-9-])', 'IgnoreCase')
                $State.DomainPatternCount = $domains.Count
            }
            $value = $State.DomainPattern.Replace($value, { param($m) & $fakeDomain $m.Value })
        }

        if ($isUri -and $State.DisplayNames -and $State.DisplayNames.Count -gt 0) {
            # A filter can name an object that a previous response returned: displayName eq 'Sales team'.
            $value = [regex]::Replace($value, "'(?<name>(?:[^']|'')+)'", {
                    param($m)
                    $name = $m.Groups['name'].Value -replace "''", "'"
                    if ($State.DisplayNames.ContainsKey($name)) { return "'" + ($State.DisplayNames[$name] -replace "'", "''") + "'" }
                    return $m.Value
                })
        }
        return $value
    }

    if ($PSCmdlet.ParameterSetName -eq 'Text') {
        $decoded = $Text
        if ($Uri) {
            # Values in a query are encoded: decode them so an address or a quoted name is seen.
            try { $decoded = [uri]::UnescapeDataString(($Text -replace '\+', '%20')) } catch { $decoded = $Text }
        }
        return (& $protectText $decoded ([bool]$Uri))
    }

    if ($null -eq $Node) { return }

    $stringOf = {
        param($child)
        if ($child -is [System.Text.Json.Nodes.JsonValue] -and $child.GetValueKind() -eq [System.Text.Json.JsonValueKind]::String) { return $child.GetValue[string]() }
        return $null
    }

    # Pass 1: learn the tenant's domains from the addresses and domain objects anywhere in the response, so that a
    # domain is replaced even where it appears before the first address that uses it.
    $collect = {
        param($current)
        if ($current -is [System.Text.Json.Nodes.JsonObject]) {
            $isDomainObject = $current.ContainsKey('isVerified') -or $current.ContainsKey('isInitial') -or $current.ContainsKey('authenticationType')
            foreach ($member in @($current)) {
                $text = & $stringOf $member.Value
                if ($null -ne $text) {
                    if (($isDomainObject -and $member.Key -in 'id', 'name') -or $member.Key -in 'domainName', 'onPremisesDomainName', 'initialDomain') { & $addDomain $text }
                    foreach ($m in [regex]::Matches($text, $emailPattern)) { & $addDomain $m.Groups['domain'].Value }
                } elseif ($null -ne $member.Value) {
                    & $collect $member.Value
                }
            }
        } elseif ($current -is [System.Text.Json.Nodes.JsonArray]) {
            foreach ($item in @($current)) {
                $text = & $stringOf $item
                if ($null -ne $text) {
                    foreach ($m in [regex]::Matches($text, $emailPattern)) { & $addDomain $m.Groups['domain'].Value }
                } elseif ($null -ne $item) {
                    & $collect $item
                }
            }
        }
    }

    $personalFields = 'givenName', 'surname', 'mailNickname', 'onPremisesSamAccountName', 'onPremisesDistinguishedName', 'onPremisesSecurityIdentifier', 'securityIdentifier', 'onPremisesImmutableId', 'employeeId', 'mobilePhone', 'businessPhones', 'faxNumber', 'streetAddress', 'postalCode', 'city', 'officeLocation', 'companyName'
    $builtInMarkers = 'roleTemplateId', 'templateId'

    $typeOf = {
        param($object)
        $odataType = & $stringOf $object['@odata.type']
        if ($odataType) { return ($odataType -replace '^#?microsoft\.graph\.', '') }
        if ($object.ContainsKey('userPrincipalName')) { return 'user' }
        if ($object.ContainsKey('groupTypes')) { return 'group' }
        if ($object.ContainsKey('servicePrincipalType')) { return 'servicePrincipal' }
        if ($object.ContainsKey('signInAudience')) { return 'application' }
        if ($object.ContainsKey('deviceId')) { return 'device' }
        if ($object.ContainsKey('conditions')) { return 'policy' }
        return 'object'
    }

    # Pass 2: replace.
    $replace = {
        param($current)
        if ($current -is [System.Text.Json.Nodes.JsonObject]) {
            $id = & $stringOf $current['id']
            $ownerTenant = & $stringOf $current['appOwnerOrganizationId']
            $isBuiltIn = $current.ContainsKey('isBuiltIn') -and $current['isBuiltIn'] -is [System.Text.Json.Nodes.JsonValue] -and $current['isBuiltIn'].GetValueKind() -eq [System.Text.Json.JsonValueKind]::True
            $isTenantObject = $id -and $id -match "^$guidPattern$" -and -not ($wellKnown -and $wellKnown.Contains($id)) -and -not $isBuiltIn -and
                -not ($builtInMarkers | Where-Object { $current.ContainsKey($_) }) -and -not ($ownerTenant -and $wellKnown -and $wellKnown.Contains($ownerTenant))

            foreach ($name in @(foreach ($member in $current) { $member.Key })) {
                $child = $current[$name]
                $text = & $stringOf $child
                if ($name -eq 'displayName' -and $null -ne $text -and $isTenantObject) {
                    $fake = '{0}-{1}' -f (& $typeOf $current), (& $fakeHash 'name' $text).Substring(0, 6)
                    if ($State.DisplayNames) { $State.DisplayNames[$text] = $fake }
                    $current[$name] = [System.Text.Json.Nodes.JsonValue]::Create([string]$fake)
                } elseif ($name -in $personalFields -and $null -ne $child) {
                    if ($null -ne $text) {
                        $current[$name] = [System.Text.Json.Nodes.JsonValue]::Create([string]('redacted-{0}' -f (& $fakeHash 'personal' $text).Substring(0, 6)))
                    } elseif ($child -is [System.Text.Json.Nodes.JsonArray]) {
                        for ($i = 0; $i -lt $child.Count; $i++) {
                            $itemText = & $stringOf $child[$i]
                            if ($null -ne $itemText) { $child[$i] = [System.Text.Json.Nodes.JsonValue]::Create([string]('redacted-{0}' -f (& $fakeHash 'personal' $itemText).Substring(0, 6))) }
                        }
                    }
                } elseif ($null -ne $text) {
                    $new = & $protectText $text $false
                    if ($new -cne $text) { $current[$name] = [System.Text.Json.Nodes.JsonValue]::Create([string]$new) }
                } elseif ($null -ne $child) {
                    & $replace $child
                }

                # A member named by a GUID (a map keyed by object id) is renamed too.
                if ($name -match "^$guidPattern$") {
                    $newName = & $fakeGuid $name
                    if ($newName -cne $name) {
                        $value = $current[$name]
                        $null = $current.Remove($name)
                        $current.Add($newName, $value)
                    }
                }
            }
        } elseif ($current -is [System.Text.Json.Nodes.JsonArray]) {
            for ($i = 0; $i -lt $current.Count; $i++) {
                $item = $current[$i]
                $text = & $stringOf $item
                if ($null -ne $text) {
                    $new = & $protectText $text $false
                    if ($new -cne $text) { $current[$i] = [System.Text.Json.Nodes.JsonValue]::Create([string]$new) }
                } elseif ($null -ne $item) {
                    & $replace $item
                }
            }
        }
    }

    & $collect $Node
    & $replace $Node
}
