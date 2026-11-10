function Get-MtLdapServiceAccount {
    <#
    .SYNOPSIS
    Collects gMSA identity and managed-password retrieval authorization without requesting the password.
    .NOTES
    Author: Mario Contestabile
    LinkedIn: https://www.linkedin.com/in/mario-contestabile/
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,
        [string] $SearchBase
    )

    if ([string]::IsNullOrWhiteSpace($SearchBase)) {
        $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext
    }

    function ConvertTo-MtGmsaSidFilterValue {
        param([Parameter(Mandatory)][object]$Sid)

        # Convert the textual SID to the escaped little-endian binary form required by an LDAP objectSid equality filter.
        $sidValue = if ($null -ne $Sid.PSObject.Properties['Value']) { [string]$Sid.Value } else { [string]$Sid }
        $parts = $sidValue -split '-'
        if ($parts.Count -lt 4 -or $parts[0] -ne 'S') { return $null }

        $bytes = [System.Collections.Generic.List[byte]]::new()
        $bytes.Add([byte]$parts[1])
        $bytes.Add([byte]($parts.Count - 3))
        $authority = [uint64]$parts[2]
        for ($shift = 40; $shift -ge 0; $shift -= 8) {
            $bytes.Add([byte](($authority -shr $shift) -band 0xff))
        }
        for ($index = 3; $index -lt $parts.Count; $index++) {
            $bytes.AddRange([BitConverter]::GetBytes([uint32]$parts[$index]))
        }
        return (($bytes | ForEach-Object { '\{0:x2}' -f $_ }) -join '')
    }

    # Request the authorization descriptor only. The managed-password value is intentionally excluded.
    $attributes = @(
        'distinguishedName','name','sAMAccountName','dNSHostName','whenCreated','whenChanged',
        'objectSid','msDS-GroupMSAMembership'
    )
    $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter '(objectClass=msDS-GroupManagedServiceAccount)' -Attributes $attributes)

    $broadSidMap = [ordered]@{
        'S-1-1-0'='Everyone'
        'S-1-5-7'='Anonymous Logon'
        'S-1-5-11'='Authenticated Users'
    }

    # Cache SID lookups for this collection because the same host or group often authorizes several gMSAs.
    $sidResolutionCache = @{}

    return @($entries | ForEach-Object {
        $entry = $_
        $descriptorError = $null
        $descriptorStatus = 'Unknown'
        $descriptor = $null
        $rawDescriptor = $entry.'msDS-GroupMSAMembership'

        if ($null -eq $rawDescriptor) {
            $descriptorStatus = 'AuthorizationDescriptorAbsent'
        } else {
            if ($null -ne $rawDescriptor.PSObject.Properties['Value']) {
                $rawDescriptor = $rawDescriptor.Value
            }
            while ($rawDescriptor -is [System.Array] -and $rawDescriptor -isnot [byte[]]) {
                $items=@($rawDescriptor)
                $allBytes=$items.Count -gt 0 -and @($items|Where-Object{$_ -isnot [byte] -and -not($_ -is [int] -and $_ -ge 0 -and $_ -le 255)}).Count -eq 0
                if($allBytes){$rawDescriptor=[byte[]]@($items|ForEach-Object{[byte]$_});break}
                if($items.Count -eq 0){$descriptorStatus='AuthorizationDescriptorEmpty';break}
                if($items.Count -ne 1){$descriptorStatus='AuthorizationDescriptorUnsupportedShape';$descriptorError="Authorization descriptor returned $($items.Count) values.";break}
                $rawDescriptor=$items[0]
                if ($null -ne $rawDescriptor -and $null -ne $rawDescriptor.PSObject.Properties['Value']) {$rawDescriptor=$rawDescriptor.Value}
            }

            if($rawDescriptor -is [byte[]]){
                if($rawDescriptor.Length -eq 0){
                    $descriptorStatus='AuthorizationDescriptorEmpty'
                } else {
                    try{
                        $descriptor=ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $rawDescriptor
                        if($null -ne $descriptor){$descriptorStatus='Complete'}else{$descriptorStatus='AuthorizationDescriptorParseFailure';$descriptorError='Security descriptor parser returned no result.'}
                    }catch{$descriptorStatus='AuthorizationDescriptorParseFailure';$descriptorError=$_.Exception.Message}
                }
            } elseif($descriptorStatus -eq 'Unknown') {
                $descriptorStatus='AuthorizationDescriptorUnsupportedShape'
                $descriptorError="Unsupported authorization descriptor type: $($rawDescriptor.GetType().FullName)"
            }
        }

        $trustees=@()
        if($null -ne $descriptor){
            $trustees=@($descriptor.Access | Where-Object {$_.AccessControlType -eq 'Allow'} | ForEach-Object {
                $ace = $_
                $sid=[string]$ace.Sid
                $resolution = $null

                if($broadSidMap.Contains($sid)){
                    $resolution=[pscustomobject][ordered]@{
                        Status='WellKnownBroadPrincipal';Name=$broadSidMap[$sid];SamAccountName=$null
                        DistinguishedName=$null;ObjectClass=$null;Error=$null
                    }
                } elseif($sidResolutionCache.ContainsKey($sid)) {
                    $resolution=$sidResolutionCache[$sid]
                } else {
                    try {
                        $sidFilter=ConvertTo-MtGmsaSidFilterValue -Sid $sid
                        if($null -eq $sidFilter){
                            $resolution=[pscustomobject][ordered]@{Status='ResolutionError';Name=$null;SamAccountName=$null;DistinguishedName=$null;ObjectClass=$null;Error='SID could not be converted to an LDAP filter value.'}
                        } else {
                            # Resolve the authorized SID through LDAP without reading the managed-password attribute.
                            $principal=Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter "(objectSid=$sidFilter)" -Attributes @('distinguishedName','name','sAMAccountName','objectClass','objectSid') -PageSize 0 | Select-Object -First 1
                            if($null -eq $principal){
                                $resolution=[pscustomobject][ordered]@{Status='Unresolved';Name=$null;SamAccountName=$null;DistinguishedName=$null;ObjectClass=$null;Error=$null}
                            } else {
                                $classes=@($principal.objectClass)
                                $leafClass=if($classes.Count){[string]$classes[-1]}else{$null}
                                $status=switch -Regex ($leafClass) {
                                    '^group$' {'ResolvedGroup';break}
                                    '^computer$' {'ResolvedComputer';break}
                                    '^user$' {'ResolvedUser';break}
                                    '^foreignSecurityPrincipal$' {'ForeignSecurityPrincipal';break}
                                    default {'ResolvedPrincipal'}
                                }
                                $resolution=[pscustomobject][ordered]@{
                                    Status=$status;Name=[string]$principal.name;SamAccountName=[string]$principal.sAMAccountName
                                    DistinguishedName=[string]$principal.DistinguishedName;ObjectClass=$leafClass;Error=$null
                                }
                            }
                        }
                    } catch {
                        $resolution=[pscustomobject][ordered]@{Status='ResolutionError';Name=$null;SamAccountName=$null;DistinguishedName=$null;ObjectClass=$null;Error=$_.Exception.Message}
                    }
                    $sidResolutionCache[$sid]=$resolution
                }

                $isUnresolved=$resolution.Status -in @('Unresolved','ResolutionError','ForeignSecurityPrincipal')
                [pscustomobject][ordered]@{
                    Sid=$sid
                    Name=if($resolution.Name){$resolution.Name}else{[string]$ace.IdentityReference}
                    SamAccountName=$resolution.SamAccountName
                    DistinguishedName=$resolution.DistinguishedName
                    ObjectClass=$resolution.ObjectClass
                    ResolutionStatus=$resolution.Status
                    ResolutionError=$resolution.Error
                    Classification=if($broadSidMap.Contains($sid)){'Broad'}elseif($isUnresolved){'Unresolved'}else{'Delegated'}
                    BroadPrincipalName=if($broadSidMap.Contains($sid)){$broadSidMap[$sid]}else{$null}
                    AccessMask=$ace.AccessMask
                    IsInherited=[bool]$ace.IsInherited
                    AuthorizationSource='msDS-GroupMSAMembership'
                    AuthorizationType=if($resolution.Status -eq 'ResolvedGroup'){'DirectGroup'}else{'DirectPrincipal'}
                    NestedExpansionStatus=if($resolution.Status -eq 'ResolvedGroup'){'NotEvaluated'}else{'NotApplicable'}
                }
            })
        }

        [pscustomobject][ordered]@{
            DistinguishedName=[string]$entry.DistinguishedName
            Name=[string]$entry.name
            SamAccountName=[string]$entry.sAMAccountName
            DnsHostName=[string]$entry.dNSHostName
            Created=$entry.whenCreated
            Modified=$entry.whenChanged
            Sid=$entry.objectSid
            ObjectClass=@('msDS-GroupManagedServiceAccount')
            ServiceAccountType='GroupManagedServiceAccount'
            Enabled=$true
            PasswordRetrievalTrustees=$trustees
            BroadPasswordRetrievalTrustees=@($trustees|Where-Object Classification -eq 'Broad')
            UnresolvedPasswordRetrievalTrustees=@($trustees|Where-Object Classification -eq 'Unresolved')
            AuthorizationEvidenceComplete=($descriptorStatus -eq 'Complete')
            AuthorizationEvidenceStatus=$descriptorStatus
            AuthorizationCollectionError=$descriptorError
        }
    })
}