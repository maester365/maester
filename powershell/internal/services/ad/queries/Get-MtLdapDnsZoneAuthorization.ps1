function Get-MtLdapDnsZoneAuthorization {
    <#
    .SYNOPSIS
    Collects authorization ACEs from AD-integrated DNS zone objects.
    .DESCRIPTION
    Discovers DNS application naming contexts, resolves the dnsNode schema class GUID, reads each dnsZone
    DACL, and classifies applicable write authorization. The function performs LDAP reads only.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,
        [Parameter(Mandatory)]
        [PSCustomObject] $RootDse
    )
    $zeroGuid = [guid]::Empty.ToString()
    $writeRights = @('CreateChild','DeleteChild','WriteProperty','GenericWrite','GenericAll','WriteDacl','WriteOwner')
    $broadSidMap = [ordered]@{
        'S-1-1-0' = 'Everyone'
        'S-1-5-11' = 'Authenticated Users'
        'S-1-5-7' = 'Anonymous Logon'
    }
    $domainSid = $null
    try {
        $domain = Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.DefaultNamingContext -Scope Base -Filter '(objectClass=domainDNS)' -Attributes @('objectSid') -PageSize 0 | Select-Object -First 1
        if ($null -ne $domain.objectSid) { $domainSid = [string]$domain.objectSid.Value }
    } catch { Write-Verbose "Could not resolve the domain SID: $($_.Exception.Message)" }
    if ($domainSid) {
        $broadSidMap["$domainSid-513"] = 'Domain Users'
        $broadSidMap["$domainSid-554"] = 'Pre-Windows 2000 Compatible Access'
    }
    $dnsNodeSchema = Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.SchemaNamingContext -Scope Subtree -Filter '(&(objectClass=classSchema)(lDAPDisplayName=dnsNode))' -Attributes @('schemaIDGUID') -PageSize 0 | Select-Object -First 1

    # Maester LDAP values can be scalar, wrapped in a Value property, or returned as a single-item object array; normalize before GUID conversion.
    $schemaGuidRaw = if ($null -ne $dnsNodeSchema) { $dnsNodeSchema.schemaIDGUID } else { $null }
    if ($null -ne $schemaGuidRaw -and $null -ne $schemaGuidRaw.PSObject.Properties['Value']) {
        $schemaGuidRaw = $schemaGuidRaw.Value
    }
    while ($schemaGuidRaw -is [System.Array] -and $schemaGuidRaw -isnot [byte[]]) {
        $schemaGuidItems = @($schemaGuidRaw)

        # System.DirectoryServices.Protocols can surface an octet string as Object[16]; convert that exact shape back to the schema GUID byte array.
        $allByteValues = $schemaGuidItems.Count -eq 16 -and @(
            $schemaGuidItems | Where-Object {
                $_ -isnot [byte] -and -not ($_ -is [int] -and $_ -ge 0 -and $_ -le 255)
            }
        ).Count -eq 0
        if ($allByteValues) {
            $schemaGuidRaw = [byte[]]@($schemaGuidItems | ForEach-Object { [byte]$_ })
            break
        }

        if ($schemaGuidItems.Count -ne 1) {
            throw "dnsNode schemaIDGUID returned $($schemaGuidItems.Count) non-byte values; expected one wrapped value or 16 byte values."
        }
        $schemaGuidRaw = $schemaGuidItems[0]
        if ($null -ne $schemaGuidRaw -and $null -ne $schemaGuidRaw.PSObject.Properties['Value']) {
            $schemaGuidRaw = $schemaGuidRaw.Value
        }
    }

    $dnsNodeGuid = if ($schemaGuidRaw -is [byte[]]) {
        if ($schemaGuidRaw.Length -ne 16) { throw "dnsNode schemaIDGUID byte length was $($schemaGuidRaw.Length), expected 16." }
        ([guid]::new($schemaGuidRaw)).ToString()
    } elseif ($null -ne $schemaGuidRaw -and -not [string]::IsNullOrWhiteSpace([string]$schemaGuidRaw)) {
        ([guid][string]$schemaGuidRaw).ToString()
    } else {
        $null
    }
    $namingContexts = @($RootDse.NamingContexts | Where-Object { $_ -match '^(DC=DomainDnsZones|DC=ForestDnsZones),' })
    if ($namingContexts.Count -eq 0) {
        $namingContexts = @("DC=DomainDnsZones,$($RootDse.DefaultNamingContext)","DC=ForestDnsZones,$($RootDse.RootDomainNamingContext)") | Select-Object -Unique
    }
    $flags = [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
    $zones = [Collections.Generic.List[object]]::new()
    $aces = [Collections.Generic.List[object]]::new()
    $errors = [Collections.Generic.List[object]]::new()
    foreach ($context in $namingContexts) {
        try {
            $zoneBase = "CN=MicrosoftDNS,$context"
            $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $zoneBase -Scope OneLevel -Filter '(objectClass=dnsZone)' -Attributes @('distinguishedName','name','ntSecurityDescriptor') -SecurityDescriptorFlags $flags -PageSize 1000)
            foreach ($entry in $entries) {
                $descriptor = $entry.ntSecurityDescriptor
                if ($descriptor -is [byte[]]) { $descriptor = ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor }
                $zone = [pscustomobject][ordered]@{ ZoneName=[string]$entry.name; DistinguishedName=[string]$entry.DistinguishedName; NamingContext=$context; AclReadable=($null -ne $descriptor); AceCount=if($null -ne $descriptor){@($descriptor.Access).Count}else{0} }
                $zones.Add($zone)
                foreach ($ace in @($descriptor.Access)) {
                    $rightsText=[string]$ace.ActiveDirectoryRights
                    $matched=@($writeRights | Where-Object { $rightsText -match "(^|,\s*)$([regex]::Escape($_))(,|$)" })
                    if ($matched.Count -eq 0) { continue }
                    $sid=[string]$ace.Sid
                    $identity=[string]$ace.IdentityReference
                    $isUnresolved = -not [string]::IsNullOrWhiteSpace($sid) -and ($identity -eq $sid -or [string]::IsNullOrWhiteSpace($identity))
                    $objectType=[string]$ace.ObjectType
                    $inheritedObjectType=[string]$ace.InheritedObjectType
                    $createDeleteApplicable = $objectType -eq $zeroGuid -or ($dnsNodeGuid -and $objectType -eq $dnsNodeGuid)
                    $inheritApplicable = $inheritedObjectType -eq $zeroGuid -or ($dnsNodeGuid -and $inheritedObjectType -eq $dnsNodeGuid)
                    $hasCreateDelete = @($matched | Where-Object { $_ -in 'CreateChild','DeleteChild' }).Count -gt 0
                    $otherWrite = @($matched | Where-Object { $_ -notin 'CreateChild','DeleteChild' }).Count -gt 0
                    $applies = $inheritApplicable -and ($otherWrite -or ($hasCreateDelete -and $createDeleteApplicable)) -and ([string]$ace.AceFlags -notmatch 'InheritOnly')
                    $aces.Add([pscustomobject][ordered]@{
                        ZoneName=[string]$entry.name; ZoneDistinguishedName=[string]$entry.DistinguishedName; NamingContext=$context
                        TrusteeSid=$sid; TrusteeName=$identity; TrusteeClassification=if($broadSidMap.Contains($sid)){'Broad'}elseif($isUnresolved){'Unresolved'}else{'Delegated'}
                        BroadPrincipalName=if($broadSidMap.Contains($sid)){$broadSidMap[$sid]}else{$null}
                        AccessControlType=[string]$ace.AccessControlType; ActiveDirectoryRights=$rightsText; MatchedWriteRights=$matched
                        ObjectType=$objectType; InheritedObjectType=$inheritedObjectType; IsInherited=[bool]$ace.IsInherited
                        AppliesToDnsNode=[bool]$applies; IsCandidate=[bool]($applies -and $ace.AccessControlType -eq 'Allow')
                    })
                }
            }
        } catch {
            $errors.Add([pscustomobject]@{ NamingContext=$context; Error=$_.Exception.Message })
        }
    }
    [pscustomobject][ordered]@{
        DnsNodeSchemaGuid=$dnsNodeGuid; Zones=@($zones); ZoneAclEntries=@($aces)
        BroadPrincipalAces=@($aces | Where-Object { $_.TrusteeClassification -eq 'Broad' -and $_.IsCandidate })
        UnresolvedTrusteeAces=@($aces | Where-Object { $_.TrusteeClassification -eq 'Unresolved' -and $_.IsCandidate })
        CollectionErrors=@($errors); Coverage=[pscustomobject]@{ NamingContextCount=$namingContexts.Count; ZoneCount=$zones.Count; ReadableZoneCount=@($zones|Where-Object AclReadable).Count }
    }
}