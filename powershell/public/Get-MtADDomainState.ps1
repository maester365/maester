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

        [string]$ComputerName
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

            $resolvedComputerName = if ($ComputerName) {
                $ComputerName
            }
            elseif ($domainState.Domain.DnsRoot) {
                $domainState.Domain.DnsRoot
            }
            else {
                $protocolConnectionState.ResolvedServer
            }

            $smbConfigurations = @()
            foreach ($dc in $domainState.DomainControllers) {
                $dcName = if ($dc.DnsHostName) { $dc.DnsHostName } else { $dc.Name }
                try {
                    $smbConfig = Invoke-Command -ComputerName $dcName -ScriptBlock {
                        Get-SmbServerConfiguration -ErrorAction SilentlyContinue | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, EnableSecuritySignature, RequireSecuritySignature, EnableSMB3_1_1Protocol
                    } -ErrorAction SilentlyContinue
                    if ($smbConfig) {
                        $smbConfig | Add-Member -NotePropertyName 'DCName' -NotePropertyValue $dcName -Force
                        $smbConfigurations += $smbConfig
                    }
                }
                catch {
                    Write-Verbose "Could not retrieve SMB configuration from $dcName`: $($_.Exception.Message)"
                }
            }
            $domainState['SmbConfigurations'] = $smbConfigurations

            try {
                $dnsZones = Get-DnsServerZone -ComputerName $resolvedComputerName -ErrorAction Stop | Select-Object *
                $domainState['DNSZones'] = @($dnsZones)

                $dnsRecords = @()
                foreach ($zone in $dnsZones | Where-Object { $_.ZoneType -eq 'Primary' -or $_.ZoneType -eq 'ActiveDirectory-Integrated' } | Select-Object -First 20) {
                    try {
                        $records = Get-DnsServerResourceRecord -ComputerName $resolvedComputerName -ZoneName $zone.ZoneName -ErrorAction SilentlyContinue | Select-Object *
                        foreach ($record in $records) {
                            $record | Add-Member -NotePropertyName 'ZoneName' -NotePropertyValue $zone.ZoneName -Force
                        }
                        $dnsRecords += $records
                    }
                    catch {
                        Write-Verbose "Could not retrieve records for zone $($zone.ZoneName): $($_.Exception.Message)"
                    }
                }
                $domainState['DNSRecords'] = $dnsRecords
            }
            catch [Management.Automation.CommandNotFoundException] {
                Write-Verbose 'DnsServer module not available. DNS data will not be collected.'
            }
            catch {
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
