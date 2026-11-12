function Get-MtLdapDnsZoneAuthorization {
    <#
    .SYNOPSIS
    Collects authorization ACEs from AD-integrated DNS zone objects.
    .DESCRIPTION
    Discovers DNS application naming contexts, resolves dnsNode and dnsRecord schema GUIDs, reads each
    dnsZone DACL, and classifies applicable write authorization. The function performs LDAP reads only.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,
        [Parameter(Mandatory)]
        [PSCustomObject] $RootDse
    )

    function ConvertTo-MtDnsSchemaGuid {
        param([object]$Value,[string]$Name)
        if ($null -ne $Value -and $null -ne $Value.PSObject.Properties['Value']) { $Value=$Value.Value }
        while ($Value -is [System.Array] -and $Value -isnot [byte[]]) {
            $items=@($Value)
            $allBytes=$items.Count -eq 16 -and @($items|Where-Object{$_ -isnot [byte] -and -not($_ -is [int] -and $_ -ge 0 -and $_ -le 255)}).Count -eq 0
            if($allBytes){$Value=[byte[]]@($items|ForEach-Object{[byte]$_});break}
            if($items.Count -ne 1){throw "$Name schemaIDGUID returned $($items.Count) non-byte values; expected one wrapped value or 16 byte values."}
            $Value=$items[0]
            if ($null -ne $Value -and $null -ne $Value.PSObject.Properties['Value']) { $Value=$Value.Value }
        }
        if($Value -is [byte[]]){if($Value.Length-ne16){throw "$Name schemaIDGUID byte length was $($Value.Length), expected 16."};return ([guid]::new($Value)).ToString()}
        if($null-ne$Value -and -not[string]::IsNullOrWhiteSpace([string]$Value)){return ([guid][string]$Value).ToString()}
        return $null
    }

    $zeroGuid=[guid]::Empty.ToString()
    $writeRights=@('CreateChild','DeleteChild','WriteProperty','GenericWrite','GenericAll','WriteDacl','WriteOwner')
    $broadSidMap=[ordered]@{
        'S-1-1-0'='Everyone';'S-1-5-11'='Authenticated Users';'S-1-5-7'='Anonymous Logon'
        'S-1-5-32-554'='Pre-Windows 2000 Compatible Access'
    }
    try{
        $domain=Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.DefaultNamingContext -Scope Base -Filter '(objectClass=domainDNS)' -Attributes @('objectSid') -PageSize 0|Select-Object -First 1
        if($null-ne$domain.objectSid){$domainSid=[string]$domain.objectSid.Value;if($domainSid){$broadSidMap["$domainSid-513"]='Domain Users'}}
    }catch{Write-Verbose "Could not resolve the domain SID: $($_.Exception.Message)"}

    $dnsNodeSchema=Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.SchemaNamingContext -Scope Subtree -Filter '(&(objectClass=classSchema)(lDAPDisplayName=dnsNode))' -Attributes @('schemaIDGUID') -PageSize 0|Select-Object -First 1
    $dnsNodeGuid=ConvertTo-MtDnsSchemaGuid -Value $(if($dnsNodeSchema){$dnsNodeSchema.schemaIDGUID}) -Name 'dnsNode'
    $dnsRecordSchemas=@(Invoke-MtLdapSearch -Connection $Connection -SearchBase $RootDse.SchemaNamingContext -Scope Subtree -Filter '(&(objectClass=attributeSchema)(lDAPDisplayName=dnsRecord))' -Attributes @('schemaIDGUID') -PageSize 0)
    $dnsRecordGuids=@($dnsRecordSchemas|ForEach-Object{ConvertTo-MtDnsSchemaGuid -Value $_.schemaIDGUID -Name 'dnsRecord'}|Where-Object{$_}|Select-Object -Unique)

    $namingContexts=@($RootDse.NamingContexts|Where-Object{$_ -match '^(DC=DomainDnsZones|DC=ForestDnsZones),'})
    if($namingContexts.Count-eq0){$namingContexts=@("DC=DomainDnsZones,$($RootDse.DefaultNamingContext)","DC=ForestDnsZones,$($RootDse.RootDomainNamingContext)")|Select-Object -Unique}
    $flags=[System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Dacl
    $zones=[Collections.Generic.List[object]]::new();$aces=[Collections.Generic.List[object]]::new();$errors=[Collections.Generic.List[object]]::new()
    foreach($context in $namingContexts){
        try{
            $entries=@(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=MicrosoftDNS,$context" -Scope OneLevel -Filter '(objectClass=dnsZone)' -Attributes @('distinguishedName','name','ntSecurityDescriptor') -SecurityDescriptorFlags $flags -PageSize 1000)
            foreach($entry in $entries){
                $descriptor=$entry.ntSecurityDescriptor;if($descriptor-is[byte[]]){$descriptor=ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor}
                $zones.Add([pscustomobject][ordered]@{ZoneName=[string]$entry.name;DistinguishedName=[string]$entry.DistinguishedName;NamingContext=$context;AclReadable=($null-ne$descriptor);AceCount=if($descriptor){@($descriptor.Access).Count}else{0}})
                foreach($ace in @($descriptor.Access)){
                    $rightsText=[string]$ace.ActiveDirectoryRights;$matched=@($writeRights|Where-Object{$rightsText-match"(^|,\s*)$([regex]::Escape($_))(,|$)"});if(-not$matched.Count){continue}
                    $sid=[string]$ace.Sid;$identity=[string]$ace.IdentityReference;$isUnresolved=$sid-and($identity-eq$sid-or[string]::IsNullOrWhiteSpace($identity))
                    $objectType=[string]$ace.ObjectType;$inheritedObjectType=[string]$ace.InheritedObjectType
                    $aceFlags=[string]$ace.AceFlags
                    $isInheritOnly=$aceFlags-match'InheritOnly'
                    $inheritsToChildren=$aceFlags-match'(ContainerInherit|ObjectInherit)'
                    $hasCreateDelete=@($matched|Where-Object{$_ -in @('CreateChild','DeleteChild')}).Count-gt0
                    $createDeleteApplicable=$objectType-eq$zeroGuid-or($dnsNodeGuid-and$objectType-eq$dnsNodeGuid)
                    $hasWriteProperty=$matched-contains'WriteProperty'
                    $writePropertyTargetsDnsRecord=$objectType-eq$zeroGuid-or$objectType-in$dnsRecordGuids
                    $childClassApplicable=$inheritedObjectType-eq$zeroGuid-or($dnsNodeGuid-and$inheritedObjectType-eq$dnsNodeGuid)
                    $writePropertyApplicable=$hasWriteProperty-and$writePropertyTargetsDnsRecord-and$inheritsToChildren-and$childClassApplicable
                    $hasGlobalWrite=@($matched|Where-Object{$_ -in @('GenericWrite','GenericAll','WriteDacl','WriteOwner')}).Count-gt0
                    # Create/DeleteChild and global rights are evaluated on the zone object itself. InheritedObjectType
                    # constrains child inheritance and does not invalidate rights already effective on the zone.
                    $zoneObjectApplicable=($hasCreateDelete-and$createDeleteApplicable)-or$hasGlobalWrite
                    # InheritOnly prevents the ACE from applying to the zone object itself. It does not prevent
                    # inheritable WriteProperty authorization from applying to a matching dnsNode child.
                    $zoneObjectApplies=$zoneObjectApplicable-and(-not$isInheritOnly)
                    $applies=$zoneObjectApplies-or$writePropertyApplicable
                    $aces.Add([pscustomobject][ordered]@{ZoneName=[string]$entry.name;ZoneDistinguishedName=[string]$entry.DistinguishedName;NamingContext=$context;TrusteeSid=$sid;TrusteeName=$identity;TrusteeClassification=if($broadSidMap.Contains($sid)){'Broad'}elseif($isUnresolved){'Unresolved'}else{'Delegated'};BroadPrincipalName=if($broadSidMap.Contains($sid)){$broadSidMap[$sid]}else{$null};AccessControlType=[string]$ace.AccessControlType;ActiveDirectoryRights=$rightsText;MatchedWriteRights=$matched;ObjectType=$objectType;InheritedObjectType=$inheritedObjectType;IsInherited=[bool]$ace.IsInherited;AppliesToDnsNode=[bool]$applies;IsCandidate=[bool]($applies-and$ace.AccessControlType-eq'Allow')})
                }
            }
        }catch{$errors.Add([pscustomobject]@{NamingContext=$context;Error=$_.Exception.Message})}
    }
    [pscustomobject][ordered]@{DnsNodeSchemaGuid=$dnsNodeGuid;DnsRecordSchemaGuids=$dnsRecordGuids;Zones=@($zones);ZoneAclEntries=@($aces);BroadPrincipalAces=@($aces|Where-Object{$_.TrusteeClassification-eq'Broad'-and$_.IsCandidate});UnresolvedTrusteeAces=@($aces|Where-Object{$_.TrusteeClassification-eq'Unresolved'-and$_.IsCandidate});CollectionErrors=@($errors);Coverage=[pscustomobject]@{NamingContextCount=$namingContexts.Count;ZoneCount=$zones.Count;ReadableZoneCount=@($zones|Where-Object AclReadable).Count}}
}
