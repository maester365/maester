function Get-MtADDomainState {
    <#
    .SYNOPSIS
    Collects Active Directory domain state information.

    .DESCRIPTION
    Collects comprehensive domain state including domain info, forest info,
    computers, users, groups, domain controllers, replication sites, etc.
    Results are cached for the session to avoid repeated queries.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADDomainState

    Returns cached domain state or collects if not already cached.

    .EXAMPLE
    Get-MtADDomainState -Refresh

    Forces a fresh collection of domain state data from Active Directory.

    .LINK
    https://maester.dev/docs/commands/Get-MtADDomainState
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )

    $cacheKey = 'DomainState'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD Domain State data from Active Directory'

        try {
            $domainState = @{
                Domain            = Get-ADDomain | Select-Object *
                Forest            = Get-ADForest | Select-Object *
                Computers         = Get-ADComputer -Filter * -Properties createTimeStamp, distinguishedName, enabled, isCriticalSystemObject, lastLogonDate, managedBy, modified, operatingSystem, passwordExpired, passwordLastSet, PasswordNeverExpires, PasswordNotRequired, primaryGroupId, SIDHistory, TrustedForDelegation, TrustedToAuthForDelegation, servicePrincipalName
                Users             = Get-ADUser -Filter * -Properties adminCount, CannotChangePassword, createTimeStamp, DistinguishedName, DoesNotRequirePreAuth, Enabled, HomeDirectory, isCriticalSystemObject, LastBadPasswordAttempt, LastLogonDate, LockedOut, logonHours, LogonWorkstations, managedBy, Manager, modifyTimeStamp, Name, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, primaryGroupId, ProfilePath, SamAccountName, ScriptPath, SIDHistory, servicePrincipalName, TrustedForDelegation, TrustedToAuthForDelegation, UseDESKeyOnly, userAccountControl
                Groups            = Get-ADGroup -Filter * -Properties adminCount, createTimeStamp, DistinguishedName, GroupCategory, GroupScope, isCriticalSystemObject, ManagedBy, modifyTimeStamp, SIDHistory
                ServiceAccounts   = Get-ADServiceAccount -Filter *
                DomainControllers = Get-ADDomainController -Filter *
                ReplicationSites  = Get-ADReplicationSite -Filter *
                Subnets           = Get-ADReplicationSubnet -Filter * -Properties *
                RootDSE           = Get-ADRootDSE | Select-Object *
                OptionalFeatures  = Get-ADOptionalFeature -Filter * -Properties *
                CollectionTime    = Get-Date
            }

            # Collect Replication Connection information
            try {
                $replicationConnections = Get-ADReplicationConnection -Filter * -Properties *
                $domainState['ReplicationConnections'] = $replicationConnections
            }
            catch {
                Write-Verbose "Could not collect Replication Connection data: $($_.Exception.Message)"
                $domainState['ReplicationConnections'] = @()
            }

            # Collect DFS-R Subscription information (for SYSVOL replication)
            try {
                $dfsrSubscriptions = Get-ADObject -Filter { objectClass -eq "msDFSR-Subscription" } -Properties *
                $domainState['DfsrSubscriptions'] = $dfsrSubscriptions
            }
            catch {
                Write-Verbose "Could not collect DFS-R Subscription data: $($_.Exception.Message)"
                $domainState['DfsrSubscriptions'] = @()
            }

            # Collect Trust information
            try {
                $trusts = Get-ADTrust -Filter * -Properties *
                $domainState['Trusts'] = $trusts
            }
            catch {
                Write-Verbose "Could not collect Trust data: $($_.Exception.Message)"
                $domainState['Trusts'] = @()
            }

            # Collect Organizational Units
            try {
                $organizationalUnits = Get-ADOrganizationalUnit -Filter * -Properties Name, DistinguishedName, whenCreated, whenChanged, modifyTimeStamp, createTimeStamp, ManagedBy, Description
                $domainState['OrganizationalUnits'] = $organizationalUnits
            }
            catch {
                Write-Verbose "Could not collect Organizational Unit data: $($_.Exception.Message)"
                $domainState['OrganizationalUnits'] = @()
            }

            # Collect SMB configuration from each domain controller
            $smbConfigurations = @()
            foreach ($dc in $domainState.DomainControllers) {
                try {
                    $smbConfig = Invoke-Command -ComputerName $dc.Name -ScriptBlock {
                        Get-SmbServerConfiguration -ErrorAction SilentlyContinue | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, EnableSecuritySignature, RequireSecuritySignature, EnableSMB3_1_1Protocol
                    } -ErrorAction SilentlyContinue
                    if ($smbConfig) {
                        $smbConfig | Add-Member -NotePropertyName 'DCName' -NotePropertyValue $dc.Name -Force
                        $smbConfigurations += $smbConfig
                    }
                }
                catch {
                    Write-Verbose "Could not retrieve SMB configuration from $($dc.Name): $($_.Exception.Message)"
                }
            }
            $domainState['SmbConfigurations'] = $smbConfigurations

            # Try to collect DNS data if the DnsServer module is available
            try {
                $dnsZones = Get-DnsServerZone -ErrorAction Stop | Select-Object *
                $domainState['DNSZones'] = $dnsZones

                # Collect DNS records for each zone (limit to essential record types for performance)
                $dnsRecords = @()
                foreach ($zone in $dnsZones | Where-Object { $_.ZoneType -eq 'Primary' -or $_.ZoneType -eq 'ActiveDirectory-Integrated' } | Select-Object -First 20) {
                    try {
                        $records = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -ErrorAction SilentlyContinue | Select-Object *
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
                Write-Verbose "DnsServer module not available. DNS data will not be collected."
                $domainState['DNSZones'] = @()
                $domainState['DNSRecords'] = @()
            }
            catch {
                Write-Verbose "Could not collect DNS data: $($_.Exception.Message)"
                $domainState['DNSZones'] = @()
                $domainState['DNSRecords'] = @()
            }

            # Collect Schema information
            try {
                $schemaContext = (Get-ADRootDSE).schemaNamingContext
                $schemaObjects = Get-ADObject -SearchBase $schemaContext -Filter * -Properties whenCreated, objectClass
                $domainState['SchemaObjects'] = $schemaObjects

                # Get schema version information from the schema container
                $schemaContainer = Get-ADObject -Identity $schemaContext -Properties objectVersion, whenCreated, whenChanged
                $domainState['SchemaContainer'] = $schemaContainer
            }
            catch {
                Write-Verbose "Could not collect Schema data: $($_.Exception.Message)"
                $domainState['SchemaObjects'] = @()
                $domainState['SchemaContainer'] = $null
            }

            # Collect Printer information (published printers in AD)
            try {
                $printers = Get-ADObject -Filter { objectClass -eq "printQueue" } -Properties *
                $domainState['Printers'] = $printers
            }
            catch {
                Write-Verbose "Could not collect Printer data: $($_.Exception.Message)"
                $domainState['Printers'] = @()
            }

            # Check LAPS installation status
            try {
                # Check for LAPS schema extensions (ms-Mcs-AdmPwd attribute)
                $lapsSchemaCheck = Get-ADObject -SearchBase $schemaContext -Filter { name -eq "ms-Mcs-AdmPwd" } -ErrorAction SilentlyContinue
                $domainState['LapsInstalled'] = ($null -ne $lapsSchemaCheck)
            }
            catch {
                Write-Verbose "Could not check LAPS installation status: $($_.Exception.Message)"
                $domainState['LapsInstalled'] = $false
            }

            # Collect DACL (Discretionary Access Control List) information from key AD objects
            try {
                Write-Verbose "Collecting DACL information from Active Directory objects"
                $daclEntries = @()
                
                # Get the domain DN for searching
                $domainDN = $domainState.Domain.DistinguishedName
                
                # Use DirectorySearcher to get objects with their security descriptors
                $searcher = New-Object System.DirectoryServices.DirectorySearcher
                $searcher.SearchRoot = [ADSI]"LDAP://$domainDN"
                $searcher.PageSize = 1000
                $searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
                
                # Search filter for OUs, Containers, and other important objects
                $searcher.Filter = "(|(objectClass=organizationalUnit)(objectClass=container)(objectClass=groupPolicyContainer)(objectClass=domainDNS)(objectClass=computer)(objectClass=user)(objectClass=group))"
                
                # Properties to load
                $searcher.PropertiesToLoad.Add("distinguishedName") | Out-Null
                $searcher.PropertiesToLoad.Add("objectClass") | Out-Null
                $searcher.PropertiesToLoad.Add("name") | Out-Null
                $searcher.PropertiesToLoad.Add("objectSid") | Out-Null
                $searcher.PropertiesToLoad.Add("ntsecuritydescriptor") | Out-Null
                
                $results = $searcher.FindAll()
                
                foreach ($result in $results) {
                    $objectDN = $result.Properties["distinguishedName"][0]
                    $objectClass = $result.Properties["objectClass"]
                    $objectName = $result.Properties["name"][0]
                    
                    # Safely get objectSid
                    $objectSid = $null
                    try {
                        $sidProp = $result.Properties["objectSid"]
                        if ($sidProp -and $sidProp.Count -gt 0) {
                            $objectSid = (New-Object System.Security.Principal.SecurityIdentifier($sidProp[0], 0)).Value
                        }
                    } catch {
                        $objectSid = $null
                    }
                    
                    # Get the security descriptor - it's returned as a ResultPropertyValueCollection
                    $sdProperty = $result.Properties["ntsecuritydescriptor"]
                    if ($sdProperty -and $sdProperty.Count -gt 0) {
                        $securityDescriptor = $sdProperty[0]
                        
                        if ($securityDescriptor -and $securityDescriptor.Length -gt 0) {
                            try {
                                $sd = New-Object System.DirectoryServices.ActiveDirectorySecurity
                                $sd.SetSecurityDescriptorBinaryForm($securityDescriptor)
                                
                                foreach ($ace in $sd.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
                                    $daclEntry = [PSCustomObject]@{
                                        ObjectDN = $objectDN
                                        ObjectClass = $objectClass[$objectClass.Count - 1]
                                        ObjectName = $objectName
                                        ObjectSid = $objectSid
                                        IdentityReference = $ace.IdentityReference.Value
                                        AccessControlType = $ace.AccessControlType.ToString()
                                        ActiveDirectoryRights = $ace.ActiveDirectoryRights.ToString()
                                        InheritanceType = $ace.InheritanceType.ToString()
                                        IsInherited = $ace.IsInherited
                                        ObjectType = $ace.ObjectType.ToString()
                                        InheritedObjectType = $ace.InheritedObjectType.ToString()
                                        AceFlags = $ace.AceFlags
                                    }
                                    $daclEntries += $daclEntry
                                }
                            } catch {
                                Write-Verbose "Error processing DACL for $objectDN : $($_.Exception.Message)"
                            }
                        }
                    }
                }
                
                $searcher.Dispose()
                $domainState['DaclEntries'] = $daclEntries
                Write-Verbose "Collected $($daclEntries.Count) DACL entries from Active Directory"
            }
            catch {
                Write-Verbose "Could not collect DACL data: $($_.Exception.Message)"
                $domainState['DaclEntries'] = @()
            }

            $__MtSession.ADCache[$cacheKey] = $domainState
            $__MtSession.ADCollectionTime = Get-Date

            Write-Verbose "Successfully collected AD Domain State data at $($domainState.CollectionTime)"
        }
        catch [Management.Automation.CommandNotFoundException] {
            Write-Error "The Active Directory module is not installed. Please install RSAT-AD-PowerShell or run on a domain-joined machine."
            return $null
        }
        catch {
            Write-Error "Failed to collect AD Domain State data: $($_.Exception.Message)"
            return $null
        }
    }
    else {
        Write-Verbose 'Using cached AD Domain State data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
