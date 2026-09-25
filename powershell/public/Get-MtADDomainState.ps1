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

    .PARAMETER Categories
    Specifies one or more category names to collect. When omitted, all categories
    are collected (legacy behavior). Dependencies are automatically resolved and
    collected first. Valid values: Domain, FineGrainedPasswordPolicies, Forest,
    Computers, Users, Groups, ServiceAccounts, DomainControllers, ReplicationSites,
    Subnets, OptionalFeatures, ReplicationConnections, DfsrSubscriptions, Trusts,
    OrganizationalUnits, SmbConfigurations, DNS, Configuration, Schema, Printers,
    DaclEntries.

    .EXAMPLE
    Get-MtADDomainState

    Returns cached domain state or collects if not already cached. Returns no data unless Active Directory was explicitly connected through Connect-Maester.

    .EXAMPLE
    Get-MtADDomainState -Refresh

    Forces a fresh collection of domain state data from Active Directory.

    .EXAMPLE
    Get-MtADDomainState -ComputerName dc01.contoso.com

    Collects domain state data by targeting dc01.contoso.com for supported Active Directory and DNS queries.

    .EXAMPLE
    Get-MtADDomainState -Categories Domain,Users

    Collects only the Domain and Users categories (plus any dependencies).

    .LINK
    https://maester.dev/docs/commands/Get-MtADDomainState
    #>
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param(
        [switch]$Refresh,

        [string]$ComputerName,

        [ValidateRange(1, 3600)]
        [int]$DnsTimeoutSeconds = 60,

        [ValidateRange(1, 100000)]
        [int]$MaxZoneCount = 500,

        [ValidateRange(1, 1000000)]
        [int]$MaxRecordCount = 10000,

        [ValidateSet('Domain', 'FineGrainedPasswordPolicies', 'Forest', 'Computers', 'Users', 'Groups', 'ServiceAccounts', 'DomainControllers', 'ReplicationSites', 'Subnets', 'OptionalFeatures', 'ReplicationConnections', 'DfsrSubscriptions', 'Trusts', 'OrganizationalUnits', 'SmbConfigurations', 'DNS', 'Configuration', 'Schema', 'Printers', 'DaclEntries')]
        [string[]]$Categories
    )

    if (-not (Test-MtConnection -Service ActiveDirectory)) {
        Write-Verbose 'Active Directory is not connected. Run Connect-Maester -Service ActiveDirectory before collecting domain state.'
        return $null
    }

    if (-not $__MtSession.ADConnection.ProtocolValidated) {
        Write-Verbose 'Active Directory domain collection requires a protocol-validated Connect-Maester session.'
        return $null
    }

    $isScoped = $PSBoundParameters.ContainsKey('Categories')

    # Category descriptor map: name -> @{ Properties=@(); Dependencies=@(); Collector={} }
    $categoryDescriptors = @{
        Domain = @{
            Properties   = @('Domain')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['Domain'] = Get-MtLdapDomain -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext
                return $result
            }
        }
        FineGrainedPasswordPolicies = @{
            Properties   = @('FineGrainedPasswordPolicies')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['FineGrainedPasswordPolicies'] = @(Get-MtLdapFineGrainedPasswordPolicy -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                return $result
            }
        }
        Forest = @{
            Properties   = @('Forest')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $forest = Get-MtLdapForest -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext
                if ($null -ne $forest -and $null -eq $forest.PSObject.Properties['Name']) {
                    $forest | Add-Member -NotePropertyName Name -NotePropertyValue $forest.RootDomain
                }
                $result['Forest'] = $forest
                return $result
            }
        }
        Computers = @{
            Properties   = @('Computers')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $computers = @(Get-MtLdapComputer -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($computer in $computers) {
                    $computer | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $computer.Created -Force
                    $computer | Add-Member -NotePropertyName modified -NotePropertyValue $computer.Modified -Force
                }
                $result['Computers'] = $computers
                return $result
            }
        }
        Users = @{
            Properties   = @('Users')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $users = @(Get-MtLdapUser -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($user in $users) {
                    $user | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $user.Created -Force
                    $user | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $user.Modified -Force
                }
                $result['Users'] = $users
                return $result
            }
        }
        Groups = @{
            Properties   = @('Groups')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $groups = @(Get-MtLdapGroup -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($group in $groups) {
                    $group | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $group.Created -Force
                    $group | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $group.Modified -Force
                }
                $result['Groups'] = $groups
                return $result
            }
        }
        ServiceAccounts = @{
            Properties   = @('ServiceAccounts')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['ServiceAccounts'] = @(Get-MtLdapServiceAccount -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                return $result
            }
        }
        DomainControllers = @{
            Properties   = @('DomainControllers')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['DomainControllers'] = @(Get-MtLdapDomainController -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                return $result
            }
        }
        ReplicationSites = @{
            Properties   = @('ReplicationSites')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['ReplicationSites'] = @(Get-MtLdapReplicationSite -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                return $result
            }
        }
        Subnets = @{
            Properties   = @('Subnets')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['Subnets'] = @(Get-MtLdapReplicationSubnet -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                return $result
            }
        }
        OptionalFeatures = @{
            Properties   = @('OptionalFeatures')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['OptionalFeatures'] = @(Get-MtLdapOptionalFeature -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                return $result
            }
        }
        ReplicationConnections = @{
            Properties   = @('ReplicationConnections')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['ReplicationConnections'] = @(Get-MtLdapReplicationConnection -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                return $result
            }
        }
        DfsrSubscriptions = @{
            Properties   = @('DfsrSubscriptions')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['DfsrSubscriptions'] = @(Invoke-MtLdapSearch -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext -Scope Subtree -Filter '(objectClass=msDFSR-Subscription)' -Attributes @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged', 'msDFSR-Enabled', 'msDFSR-Options'))
                return $result
            }
        }
        Trusts = @{
            Properties   = @('Trusts')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['Trusts'] = @(Get-MtLdapTrust -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                return $result
            }
        }
        OrganizationalUnits = @{
            Properties   = @('OrganizationalUnits')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $organizationalUnits = @(Get-MtLdapOrganizationalUnit -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($organizationalUnit in $organizationalUnits) {
                    $organizationalUnit | Add-Member -NotePropertyName createTimeStamp -NotePropertyValue $organizationalUnit.Created -Force
                    $organizationalUnit | Add-Member -NotePropertyName whenCreated -NotePropertyValue $organizationalUnit.Created -Force
                    $organizationalUnit | Add-Member -NotePropertyName modifyTimeStamp -NotePropertyValue $organizationalUnit.Modified -Force
                    $organizationalUnit | Add-Member -NotePropertyName whenChanged -NotePropertyValue $organizationalUnit.Modified -Force
                }
                $result['OrganizationalUnits'] = $organizationalUnits
                return $result
            }
        }
        SmbConfigurations = @{
            Properties   = @('SmbConfigurations')
            Dependencies = @('DomainControllers')
            Collector    = {
                $result = [ordered]@{}
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
                $result['SmbConfigurations'] = $smbConfigurations
                return $result
            }
        }
        DNS = @{
            Properties   = @('DNSZones', 'DNSRecords')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
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

                $result['DNSZones'] = @($dnsZones)
                $result['DNSRecords'] = @($dnsRecords)
                return $result
            }
        }
        Configuration = @{
            Properties   = @('Configuration')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['Configuration'] = Get-MtLdapConfigurationContainer -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext
                return $result
            }
        }
        Schema = @{
            Properties   = @('SchemaObjects', 'SchemaContainer', 'LapsInstalled')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $schemaObjects = @()
                try {
                    $schemaObjects = @(Get-MtLdapSchemaObject -Connection $protocolConnection -SchemaNamingContext $protocolRootDse.SchemaNamingContext)
                    $result['SchemaObjects'] = $schemaObjects
                    $result['SchemaContainer'] = $schemaObjects | Where-Object { $_.DistinguishedName -eq $protocolRootDse.SchemaNamingContext } | Select-Object -First 1
                }
                catch {
                    Write-Verbose "Could not collect Schema data: $($_.Exception.Message)"
                }

                try {
                    $result['LapsInstalled'] = [bool]($schemaObjects | Where-Object { $_.Name -eq 'ms-Mcs-AdmPwd' } | Select-Object -First 1)
                }
                catch {
                    Write-Verbose "Could not check LAPS installation status: $($_.Exception.Message)"
                }
                return $result
            }
        }
        Printers = @{
            Properties   = @('Printers')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['Printers'] = @(Get-MtLdapPrinter -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                return $result
            }
        }
        DaclEntries = @{
            Properties   = @('DaclEntries')
            Dependencies = @()
            Collector    = {
                $result = [ordered]@{}
                $result['DaclEntries'] = @(Get-MtLdapDacl -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                return $result
            }
        }
    }

    $allCategories = @(
        'Domain',
        'FineGrainedPasswordPolicies',
        'Forest',
        'Computers',
        'Users',
        'Groups',
        'ServiceAccounts',
        'DomainControllers',
        'ReplicationSites',
        'Subnets',
        'OptionalFeatures',
        'ReplicationConnections',
        'DfsrSubscriptions',
        'Trusts',
        'OrganizationalUnits',
        'SmbConfigurations',
        'DNS',
        'Configuration',
        'Schema',
        'Printers',
        'DaclEntries'
    )

    if ($isScoped) {
        $requestedCategories = $Categories
    }
    else {
        $requestedCategories = $allCategories
    }

    # Recursive topological sort for dependency resolution
    function ResolveCategoryDependency {
        param([string[]]$InputCategories)
        $resolved = [System.Collections.Generic.List[string]]::new()
        $visiting = [System.Collections.Generic.HashSet[string]]::new()

        function VisitCategory {
            param([string]$Category)
            if ($resolved -contains $Category) { return }
            if ($visiting.Contains($Category)) { throw "Circular dependency detected for category: $Category" }
            [void]$visiting.Add($Category)
            foreach ($dep in $categoryDescriptors[$Category].Dependencies) {
                if (-not $categoryDescriptors.ContainsKey($dep)) { throw "Unknown dependency: $dep" }
                VisitCategory -Category $dep
            }
            [void]$visiting.Remove($Category)
            [void]$resolved.Add($Category)
        }

        foreach ($cat in $InputCategories) {
            VisitCategory -Category $cat
        }

        return $resolved
    }

    $resolvedCategories = ResolveCategoryDependency -InputCategories $requestedCategories

    $computerSuffix = if ($ComputerName) { ":$ComputerName" } else { '' }
    $metadataCacheKey = "DomainState:Metadata$computerSuffix"

    # Initialize domain state with safe defaults for all properties
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
        RootDSE                = $null
        OptionalFeatures       = @()
        CollectionTime         = $null
        ProtocolEvidence       = $null
        CollectionMode         = $null
        ReplicationConnections = @()
        DfsrSubscriptions      = @()
        Trusts                 = @()
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

    # Hydrate from cache and determine missing categories
    $cachedCategories = [System.Collections.Generic.List[string]]::new()
    $missingCategories = [System.Collections.Generic.List[string]]::new()
    $metadataFromCache = $null

    if (-not $Refresh) {
        if ($__MtSession.ADCache.ContainsKey($metadataCacheKey)) {
            $metadataFromCache = $__MtSession.ADCache[$metadataCacheKey]
        }

        foreach ($cat in $resolvedCategories) {
            $catCacheKey = "DomainState:$cat$computerSuffix"
            if ($__MtSession.ADCache.ContainsKey($catCacheKey)) {
                $cachedBag = $__MtSession.ADCache[$catCacheKey]
                foreach ($prop in $categoryDescriptors[$cat].Properties) {
                    $domainState[$prop] = $cachedBag[$prop]
                }
                [void]$cachedCategories.Add($cat)
            }
            else {
                [void]$missingCategories.Add($cat)
            }
        }
    }
    else {
        foreach ($cat in $resolvedCategories) {
            [void]$missingCategories.Add($cat)
        }
    }

    # If refresh, remove old cache entries before collection to avoid stale data on failure
    if ($Refresh) {
        if ($__MtSession.ADCache.ContainsKey($metadataCacheKey)) {
            $__MtSession.ADCache.Remove($metadataCacheKey)
        }
        foreach ($cat in $resolvedCategories) {
            $catCacheKey = "DomainState:$cat$computerSuffix"
            if ($__MtSession.ADCache.ContainsKey($catCacheKey)) {
                $__MtSession.ADCache.Remove($catCacheKey)
            }
        }
    }

    # If everything is cached (including metadata), return assembled state
    if ($missingCategories.Count -eq 0 -and $null -ne $metadataFromCache) {
        $domainState['RootDSE'] = $metadataFromCache.RootDSE
        $domainState['ProtocolEvidence'] = $metadataFromCache.ProtocolEvidence
        $domainState['CollectionMode'] = $metadataFromCache.CollectionMode
        $domainState['CollectionTime'] = $metadataFromCache.CollectionTime
        Write-Verbose 'Using cached AD Domain State data'
        return $domainState
    }

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

        $collectionTime = Get-Date
        $collectionMode = 'ProtocolOnly'

        # Cache metadata
        $metadataBag = [ordered]@{
            RootDSE          = $protocolRootDse
            ProtocolEvidence = $protocolEvidence
            CollectionMode   = $collectionMode
            CollectionTime   = $collectionTime
        }
        $__MtSession.ADCache[$metadataCacheKey] = $metadataBag

        $domainState['RootDSE'] = $protocolRootDse
        $domainState['ProtocolEvidence'] = $protocolEvidence
        $domainState['CollectionMode'] = $collectionMode
        $domainState['CollectionTime'] = $collectionTime

        $failedCategories = [System.Collections.Generic.HashSet[string]]::new()
        $anyCollectionOccurred = $false

        foreach ($cat in $missingCategories) {
            $descriptor = $categoryDescriptors[$cat]
            $collector = $descriptor.Collector

            try {
                $bag = & $collector
                if ($null -eq $bag) { $bag = [ordered]@{} }

                # Ensure all declared properties exist in the bag
                foreach ($prop in $descriptor.Properties) {
                    if (-not $bag.Contains($prop)) {
                        $bag[$prop] = $domainState[$prop]
                    }
                }

                # Copy to domain state
                foreach ($prop in $descriptor.Properties) {
                    $domainState[$prop] = $bag[$prop]
                }

                # Cache the property bag
                $catCacheKey = "DomainState:$cat$computerSuffix"
                $__MtSession.ADCache[$catCacheKey] = $bag
                $anyCollectionOccurred = $true
            }
            catch {
                [void]$failedCategories.Add($cat)
                Write-Verbose "Could not collect $cat data: $($_.Exception.Message)"
            }
        }

        if ($anyCollectionOccurred) {
            $__MtSession.ADCollectionTime = Get-Date
        }

        # Legacy behavior: DNS failure on unscoped calls removes both keys
        if (-not $isScoped -and $failedCategories.Contains('DNS')) {
            $domainState.Remove('DNSZones')
            $domainState.Remove('DNSRecords')
        }

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

    return $domainState
}
