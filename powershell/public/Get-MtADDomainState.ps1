function Get-MtADDomainState {
    <#
    .SYNOPSIS
    Collects Active Directory domain state information.

    .DESCRIPTION
    Collects comprehensive domain state including domain info, forest info,
    computers, users, groups, domain controllers, replication sites, etc.
    Results are cached for the session to avoid repeated queries.
    Connect-Maester -Service ActiveDirectory must complete successfully before this command can collect or return data.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .PARAMETER ComputerName
    Specifies an Active Directory domain controller or AD DS server to target for
    data collection. When provided, LDAP and DNS queries are directed to this
    server. If not specified, the target selected by Connect-Maester is used.

    .PARAMETER DnsTimeoutSeconds
    Specifies the timeout, in seconds, for remote DNS inventory collection.

    .PARAMETER MaxZoneCount
    Specifies the maximum number of DNS zones that may be normalized. Collection
    fails explicitly if the remote inventory exceeds this value.

    .PARAMETER MaxRecordCount
    Specifies the maximum number of DNS records that may be normalized. Collection
    fails explicitly if the remote inventory exceeds this value.

    .EXAMPLE
    Get-MtADDomainState

    Returns cached domain state or collects if not already cached. Returns no data unless Active Directory was explicitly connected through Connect-Maester.

    .EXAMPLE
    Get-MtADDomainState -Refresh

    Forces a fresh collection of domain state data from Active Directory.

    .EXAMPLE
    Get-MtADDomainState -ComputerName dc01.contoso.com

    Collects domain state data by targeting dc01.contoso.com for supported Active Directory and DNS queries.

    .LINK
    https://maester.dev/docs/commands/Get-MtADDomainState
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh,

        [string]$ComputerName,

        [ValidateRange(1, 3600)]
        [int]$DnsTimeoutSeconds = 60,

        [ValidateRange(1, 100000)]
        [int]$MaxZoneCount = 500,

        [ValidateRange(1, 1000000)]
        [int]$MaxRecordCount = 10000
    )

    if (-not (Test-MtConnection -Service ActiveDirectory)) {
        Write-Verbose 'Active Directory is not connected. Run Connect-Maester -Service ActiveDirectory before collecting domain state.'
        return $null
    }

    if (-not $__MtSession.ADConnection.ProtocolValidated) {
        Write-Verbose 'Active Directory domain collection requires a protocol-validated Connect-Maester session.'
        return $null
    }

    $cacheKey = if ($ComputerName) { "DomainState:$ComputerName" } else { 'DomainState' }

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD Domain State data from Active Directory'

        $protocolConnection = $null
        try {
            $protocolTargetParameters = @{
                AuthMode = $__MtSession.ADConnection.RequestedAuthMode
                TlsMode  = $__MtSession.ADConnection.RequestedTlsMode
                PassThru = $true
            }
            if ($ComputerName) {
                $protocolTargetParameters['ActiveDirectoryServer'] = $ComputerName
            }
            elseif ($__MtSession.ADConnection.RequestedServer) {
                $protocolTargetParameters['ActiveDirectoryServer'] = $__MtSession.ADConnection.RequestedServer
            }
            elseif ($__MtSession.ADConnection.RequestedDomain) {
                $protocolTargetParameters['ActiveDirectoryDomain'] = $__MtSession.ADConnection.RequestedDomain
            }
            elseif ($__MtSession.ADConnection.RequestedForest) {
                $protocolTargetParameters['ActiveDirectoryForest'] = $__MtSession.ADConnection.RequestedForest
            }
            if ($null -ne $__MtSession.ADCredential) {
                $protocolTargetParameters['ActiveDirectoryCredential'] = $__MtSession.ADCredential
            }

            $protocolConnectionState = Connect-MtAdTarget @protocolTargetParameters
            $ldapConnectionParameters = @{
                Server   = $protocolConnectionState.ResolvedServer
                AuthType = $protocolConnectionState.AuthenticationMode
            }
            if ($protocolConnectionState.TlsMode -eq 'StartTls') {
                $ldapConnectionParameters['Port'] = 389
                $ldapConnectionParameters['UseStartTls'] = $true
            }
            else {
                $ldapConnectionParameters['Port'] = 636
            }
            if ($null -ne $__MtSession.ADCredential) {
                $ldapConnectionParameters['Credential'] = $__MtSession.ADCredential
            }

            $protocolConnection = New-MtLdapConnection @ldapConnectionParameters
            $protocolRootDse = Get-MtLdapRootDse -Connection $protocolConnection
            $protocolEvidence = [PSCustomObject]@{
                ResolvedServer       = $protocolConnectionState.ResolvedServer
                ResolvedDomain       = $protocolConnectionState.ResolvedDomain
                ResolvedForest       = $protocolConnectionState.ResolvedForest
                AuthenticationMode   = $protocolConnectionState.AuthenticationMode
                TlsMode              = $protocolConnectionState.TlsMode
                DefaultNamingContext = $protocolRootDse.DefaultNamingContext
                VerifiedAt           = Get-Date
            }

            $domainState = [ordered]@{
                Domain                 = $null
                Forest                 = $null
                Computers              = @()
                Users                  = @()
                Groups                 = @()
                ServiceAccounts        = @()
                DomainControllers      = @()
                ReplicationSites       = @()
                Subnets                = @()
                RootDSE                = $protocolRootDse
                OptionalFeatures       = @()
                CollectionTime         = Get-Date
                ProtocolEvidence       = $protocolEvidence
                CollectionMode         = 'ProtocolOnly'
                ReplicationConnections = @()
                DfsrSubscriptions      = @()
                Trusts                  = @()
                OrganizationalUnits    = @()
                SmbConfigurations      = @()
                DNSZones               = @()
                DNSRecords             = @()
                Configuration          = $null
                SchemaObjects          = @()
                SchemaContainer        = $null
                Printers               = @()
                LapsInstalled          = $false
                DaclEntries            = @()
                FineGrainedPasswordPolicies = @()
            }

            try {
                $domainState['Domain'] = Get-MtLdapDomain -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext
            }
            catch {
                Write-Verbose "Could not collect Domain data: $($_.Exception.Message)"
            }

            try {
                $domainState['FineGrainedPasswordPolicies'] = @(Get-MtLdapFineGrainedPasswordPolicy -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
            }
            catch {
                Write-Verbose "Could not collect FGPP data: $($_.Exception.Message)"
            }

            try {
                $forest = Get-MtLdapForest -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext
                if ($null -ne $forest -and $null -eq $forest.PSObject.Properties['Name']) {
                    $forest | Add-Member -NotePropertyName Name -NotePropertyValue $forest.RootDomain
                }
                $domainState['Forest'] = $forest
            }
            catch {
                Write-Verbose "Could not collect Forest data: $($_.Exception.Message)"
            }

            try {
                $computers = @(Get-MtLdapComputer -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($computer in $computers) {
                    $computer | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $computer.Created -Force
                    $computer | Add-Member -NotePropertyName modified -NotePropertyValue $computer.Modified -Force
                }
                $domainState['Computers'] = $computers
            }
            catch {
                Write-Verbose "Could not collect Computers data: $($_.Exception.Message)"
            }

            try {
                $users = @(Get-MtLdapUser -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($user in $users) {
                    $user | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $user.Created -Force
                    $user | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $user.Modified -Force
                }
                $domainState['Users'] = $users
            }
            catch {
                Write-Verbose "Could not collect Users data: $($_.Exception.Message)"
            }

            try {
                $groups = @(Get-MtLdapGroup -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($group in $groups) {
                    $group | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $group.Created -Force
                    $group | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $group.Modified -Force
                }
                $domainState['Groups'] = $groups
            }
            catch {
                Write-Verbose "Could not collect Groups data: $($_.Exception.Message)"
            }

            try {
                $domainState['ServiceAccounts'] = @(Get-MtLdapServiceAccount -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
            }
            catch {
                Write-Verbose "Could not collect ServiceAccounts data: $($_.Exception.Message)"
            }

            try {
                $domainState['DomainControllers'] = @(Get-MtLdapDomainController -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
            }
            catch {
                Write-Verbose "Could not collect DomainControllers data: $($_.Exception.Message)"
            }

            try {
                $domainState['ReplicationSites'] = @(Get-MtLdapReplicationSite -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
            }
            catch {
                Write-Verbose "Could not collect ReplicationSites data: $($_.Exception.Message)"
            }

            try {
                $domainState['Subnets'] = @(Get-MtLdapReplicationSubnet -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
            }
            catch {
                Write-Verbose "Could not collect Subnets data: $($_.Exception.Message)"
            }

            try {
                $domainState['OptionalFeatures'] = @(Get-MtLdapOptionalFeature -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
            }
            catch {
                Write-Verbose "Could not collect OptionalFeatures data: $($_.Exception.Message)"
            }

            try {
                $domainState['ReplicationConnections'] = @(Get-MtLdapReplicationConnection -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
            }
            catch {
                Write-Verbose "Could not collect ReplicationConnections data: $($_.Exception.Message)"
            }

            try {
                $domainState['DfsrSubscriptions'] = @(Invoke-MtLdapSearch -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext -Scope Subtree -Filter '(objectClass=msDFSR-Subscription)' -Attributes @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged', 'msDFSR-Enabled', 'msDFSR-Options'))
            }
            catch {
                Write-Verbose "Could not collect DFS-R Subscription data: $($_.Exception.Message)"
            }

            try {
                $domainState['Trusts'] = @(Get-MtLdapTrust -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
            }
            catch {
                Write-Verbose "Could not collect Trust data: $($_.Exception.Message)"
            }

            try {
                $organizationalUnits = @(Get-MtLdapOrganizationalUnit -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($organizationalUnit in $organizationalUnits) {
                    $organizationalUnit | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $organizationalUnit.Created -Force
                    $organizationalUnit | Add-Member -NotePropertyName whenCreated -NotePropertyValue $organizationalUnit.Created -Force
                    $organizationalUnit | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $organizationalUnit.Modified -Force
                    $organizationalUnit | Add-Member -NotePropertyName whenChanged -NotePropertyValue $organizationalUnit.Modified -Force
                }
                $domainState['OrganizationalUnits'] = $organizationalUnits
            }
            catch {
                Write-Verbose "Could not collect Organizational Unit data: $($_.Exception.Message)"
            }

            $smbConfigurations = @()
            foreach ($dc in $domainState.DomainControllers) {
                $dcName = if ($dc.DnsHostName) { $dc.DnsHostName } else { $dc.Name }
                try {
                    $smbConfig = Invoke-MtADManagementCommand -Operation SmbConfiguration -ComputerName $dcName
                    if ($null -eq $smbConfig) {
                        Write-Verbose "Could not retrieve SMB configuration from $dcName`: The management executor returned no SMB configuration."
                        continue
                    }
                    if ($null -ne $smbConfig.PSObject.Properties['ErrorCategory']) {
                        Write-Verbose "Could not retrieve SMB configuration from $dcName`: $($smbConfig.RedactedMessage)"
                        continue
                    }

                    $smbConfigurations += [PSCustomObject][ordered]@{
                        DCName                   = [string]$smbConfig.DCName
                        EnableSMB1Protocol       = [bool]$smbConfig.EnableSMB1Protocol
                        EnableSMB2Protocol       = [bool]$smbConfig.EnableSMB2Protocol
                        EnableSMB3_1_1Protocol   = [bool]$smbConfig.EnableSMB3_1_1Protocol
                        EnableSecuritySignature  = [bool]$smbConfig.EnableSecuritySignature
                        RequireSecuritySignature = [bool]$smbConfig.RequireSecuritySignature
                    }
                }
                catch {
                    Write-Verbose "Could not retrieve SMB configuration from $dcName`: $($_.Exception.Message)"
                }
            }
            $domainState['SmbConfigurations'] = $smbConfigurations

            try {
                $dnsInventory = Invoke-MtADManagementCommand -Operation DnsInventory -TimeoutSeconds $DnsTimeoutSeconds
                if ($null -eq $dnsInventory -or $null -ne $dnsInventory.PSObject.Properties['ErrorCategory']) {
                    $dnsError = if ($null -ne $dnsInventory) { $dnsInventory.RedactedMessage } else { 'The management executor returned no DNS inventory.' }
                    throw [System.InvalidOperationException]::new($dnsError)
                }

                $wmiZones = @($dnsInventory.Zones)
                $wmiRecords = @($dnsInventory.Records)
                $wmiRootHints = @($dnsInventory.RootHints)
                if ($wmiZones.Count -gt $MaxZoneCount) {
                    throw [System.InvalidOperationException]::new("DNS inventory truncation prevented: received $($wmiZones.Count) zones, exceeding MaxZoneCount $MaxZoneCount.")
                }
                if ($wmiRecords.Count -gt $MaxRecordCount) {
                    throw [System.InvalidOperationException]::new("DNS inventory truncation prevented: received $($wmiRecords.Count) records, exceeding MaxRecordCount $MaxRecordCount.")
                }

                $getDnsPropertyValue = {
                    param(
                        [object]$InputObject,
                        [string[]]$PropertyNames
                    )

                    if ($null -eq $InputObject) {
                        return $null
                    }

                    foreach ($propertyName in $PropertyNames) {
                        $property = $InputObject.PSObject.Properties[$propertyName]
                        if ($null -ne $property -and $null -ne $property.Value) {
                            return $property.Value
                        }
                    }

                    return $null
                }

                $dnsZones = foreach ($wmiZone in $wmiZones) {
                    $zoneProperties = [ordered]@{}
                    foreach ($property in $wmiZone.PSObject.Properties) {
                        if ($property.Name -notin @('ZoneName', 'ZoneType')) {
                            $zoneProperties[$property.Name] = $property.Value
                        }
                    }

                    $wmiZoneType = & $getDnsPropertyValue -InputObject $wmiZone -PropertyNames @('ZoneType')
                    $isDsIntegrated = [bool](& $getDnsPropertyValue -InputObject $wmiZone -PropertyNames @('DsIntegrated'))
                    $zoneType = switch ([int]$wmiZoneType) {
                        1 { if ($isDsIntegrated) { 'ActiveDirectory-Integrated' } else { 'Primary' } }
                        2 { 'Secondary' }
                        3 { 'Stub' }
                        4 { 'Forwarder' }
                        default { [string]$wmiZoneType }
                    }
                    $zoneProperties['ZoneName'] = [string](& $getDnsPropertyValue -InputObject $wmiZone -PropertyNames @('Name', 'ZoneName'))
                    $zoneProperties['ZoneType'] = $zoneType
                    [PSCustomObject]$zoneProperties
                }

                if ($wmiRootHints.Count -gt 0 -and 'RootDNSServers' -notin @($dnsZones.ZoneName)) {
                    $rootHintProperties = [ordered]@{}
                    foreach ($property in $wmiRootHints[0].PSObject.Properties) {
                        if ($property.Name -notin @('ZoneName', 'ZoneType')) {
                            $rootHintProperties[$property.Name] = $property.Value
                        }
                    }
                    $rootHintProperties['ZoneName'] = 'RootDNSServers'
                    $rootHintProperties['ZoneType'] = 'Primary'
                    $dnsZones = @($dnsZones) + [PSCustomObject]$rootHintProperties
                }

                if (@($dnsZones).Count -gt $MaxZoneCount) {
                    throw [System.InvalidOperationException]::new("DNS inventory truncation prevented: normalization produced $(@($dnsZones).Count) zones, exceeding MaxZoneCount $MaxZoneCount.")
                }

                $dnsRecords = foreach ($wmiRecord in $wmiRecords) {
                    $recordProperties = [ordered]@{}
                    foreach ($property in $wmiRecord.PSObject.Properties) {
                        if ($property.Name -notin @('ZoneName', 'HostName', 'RecordType', 'RecordData', 'Timestamp', 'TTL')) {
                            $recordProperties[$property.Name] = $property.Value
                        }
                    }

                    $recordType = [string](& $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('RecordType'))
                    if ([string]::IsNullOrWhiteSpace($recordType)) {
                        $className = [string](& $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('__CLASS', 'CimClassName'))
                        if ([string]::IsNullOrWhiteSpace($className)) {
                            $cimClass = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('CimClass')
                            $className = [string](& $getDnsPropertyValue -InputObject $cimClass -PropertyNames @('CimClassName'))
                        }
                        if ([string]::IsNullOrWhiteSpace($className)) {
                            $className = @($wmiRecord.PSObject.TypeNames | Where-Object { $_ -match 'MicrosoftDNS_[A-Za-z0-9]+Type' } | Select-Object -First 1)
                        }
                        if ($className -match 'MicrosoftDNS_([A-Za-z0-9]+)Type') {
                            $recordType = $Matches[1].ToUpperInvariant()
                        }
                    }
                    if ([string]::IsNullOrWhiteSpace($recordType)) {
                        $textRepresentation = [string](& $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('TextRepresentation'))
                        if ($textRepresentation -match '(?i)\sIN\s+([A-Z0-9]+)\s') {
                            $recordType = $Matches[1].ToUpperInvariant()
                        }
                    }

                    $rawRecordData = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('RecordData')
                    $recordDataSource = if ($null -ne $rawRecordData -and $rawRecordData -isnot [string] -and $rawRecordData -isnot [ValueType]) {
                        $rawRecordData
                    }
                    else {
                        $wmiRecord
                    }
                    $recordData = switch ($recordType.ToUpperInvariant()) {
                        'SOA' {
                            [PSCustomObject][ordered]@{
                                PrimaryServer      = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('PrimaryNameServer', 'PrimaryServer')
                                ResponsibleParty   = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('ResponsiblePerson', 'ResponsibleParty')
                                SerialNumber       = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('SerialNumber')
                                RefreshInterval    = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Refresh-TTL', 'RefreshInterval')
                                RetryInterval      = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Retry-TTL', 'RetryInterval', 'RetryDelay')
                                ExpireLimit        = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Expire-TTL', 'ExpireInterval', 'ExpireLimit')
                                MinimumTimeToLive  = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Minimum-TTL', 'MinimumTimeToLive', 'MinimumTTL')
                            }
                        }
                        'SRV' {
                            [PSCustomObject][ordered]@{
                                Priority   = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Priority')
                                Weight     = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Weight')
                                Port       = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('Port')
                                DomainName = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('SRVDomainName', 'DomainName')
                            }
                        }
                        'A' {
                            $ipAddressValue = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('IPAddress', 'IPv4Address')
                            if ($null -eq $ipAddressValue) {
                                $ipAddressValue = $rawRecordData
                            }
                            try {
                                $ipAddressValue = [System.Net.IPAddress]::Parse([string]$ipAddressValue)
                            }
                            catch {
                                Write-Verbose "Could not parse DNS A record address '$ipAddressValue'."
                            }
                            [PSCustomObject][ordered]@{ IPv4Address = $ipAddressValue }
                        }
                        'NS' {
                            [PSCustomObject][ordered]@{
                                NameServer = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('NSName', 'NameServer', 'NSHost')
                            }
                        }
                        'AAAA' {
                            [PSCustomObject][ordered]@{
                                IPv6Address = & $getDnsPropertyValue -InputObject $recordDataSource -PropertyNames @('IPv6Address')
                            }
                        }
                        default {
                            [PSCustomObject][ordered]@{ Data = $rawRecordData }
                        }
                    }

                    $zoneName = [string](& $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('ContainerName'))
                    if ([string]::IsNullOrWhiteSpace($zoneName)) {
                        $zoneName = [string](& $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('DomainName'))
                    }
                    if ($zoneName -in @('.RootHints', '..RootHints', 'RootHints')) {
                        $zoneName = 'RootDNSServers'
                    }

                    $hostName = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('OwnerName')
                    if ($null -eq $hostName) {
                        $hostName = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('DomainName')
                    }
                    $timestamp = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('Timestamp', 'TimeStamp')
                    if ($null -eq $timestamp -or [uint64]$timestamp -eq 0) {
                        $timestamp = $null
                    }

                    $recordProperties['ZoneName'] = $zoneName
                    $recordProperties['HostName'] = $hostName
                    $recordProperties['RecordType'] = $recordType.ToUpperInvariant()
                    $recordProperties['RecordData'] = $recordData
                    $recordProperties['Timestamp'] = $timestamp
                    $recordProperties['TTL'] = & $getDnsPropertyValue -InputObject $wmiRecord -PropertyNames @('TTL')
                    [PSCustomObject]$recordProperties
                }

                $domainState['DNSZones'] = @($dnsZones)
                $domainState['DNSRecords'] = @($dnsRecords)
            }
            catch {
                $domainState.Remove('DNSZones')
                $domainState.Remove('DNSRecords')
                Write-Verbose "Could not collect DNS data: $($_.Exception.Message)"
            }

            try {
                $domainState['Configuration'] = Get-MtLdapConfigurationContainer -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext
            }
            catch {
                Write-Verbose "Could not collect Configuration container data: $($_.Exception.Message)"
            }

            $schemaObjects = @()
            try {
                $schemaObjects = @(Get-MtLdapSchemaObject -Connection $protocolConnection -SchemaNamingContext $protocolRootDse.SchemaNamingContext)
                $domainState['SchemaObjects'] = $schemaObjects
                $domainState['SchemaContainer'] = $schemaObjects | Where-Object { $_.DistinguishedName -eq $protocolRootDse.SchemaNamingContext } | Select-Object -First 1
            }
            catch {
                Write-Verbose "Could not collect Schema data: $($_.Exception.Message)"
            }

            try {
                $domainState['Printers'] = @(Get-MtLdapPrinter -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
            }
            catch {
                Write-Verbose "Could not collect Printer data: $($_.Exception.Message)"
            }

            try {
                $domainState['LapsInstalled'] = [bool]($schemaObjects | Where-Object { $_.Name -eq 'ms-Mcs-AdmPwd' } | Select-Object -First 1)
            }
            catch {
                Write-Verbose "Could not check LAPS installation status: $($_.Exception.Message)"
            }

            try {
                $domainState['DaclEntries'] = @(Get-MtLdapDacl -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
            }
            catch {
                Write-Verbose "Could not collect DACL data: $($_.Exception.Message)"
            }

            $__MtSession.ADCache[$cacheKey] = $domainState
            $__MtSession.ADCollectionTime = Get-Date

            Write-Verbose "Successfully collected AD Domain State data at $($domainState.CollectionTime)"
        }
        catch {
            Write-Error "Failed to collect AD Domain State data: $($_.Exception.Message)"
            return $null
        }
        finally {
            if ($null -ne $protocolConnection) {
                $protocolConnection.Dispose()
            }
        }
    }
    else {
        Write-Verbose 'Using cached AD Domain State data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
