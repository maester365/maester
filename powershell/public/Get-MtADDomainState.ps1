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
    data collection. When provided, Active Directory queries and the LDAP searcher
    are directed to this server. DNS collection also targets this host when it
    supports the required DNS management access. If not specified, commands use
    the implicit serverless behavior of the Active Directory module and the DNS
    root from the collected domain object is used for DNS queries.

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

    $cacheKey = if ($ComputerName) { "DomainState:$ComputerName" } else { 'DomainState' }

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD Domain State data from Active Directory'

        try {
            $adServerParameters = @{}
            if ($ComputerName) {
                $adServerParameters['Server'] = $ComputerName
            }

            $domainState = @{
                Domain            = Get-ADDomain @adServerParameters | Select-Object *
                Forest            = Get-ADForest @adServerParameters | Select-Object *
                Computers         = Get-ADComputer -Filter * -Properties createTimeStamp, distinguishedName, enabled, isCriticalSystemObject, lastLogonDate, managedBy, modified, operatingSystem, passwordExpired, passwordLastSet, PasswordNeverExpires, PasswordNotRequired, primaryGroupId, SIDHistory, TrustedForDelegation, TrustedToAuthForDelegation, servicePrincipalName @adServerParameters
                Users             = Get-ADUser -Filter * -Properties adminCount, CannotChangePassword, createTimeStamp, DistinguishedName, DoesNotRequirePreAuth, Enabled, HomeDirectory, isCriticalSystemObject, LastBadPasswordAttempt, LastLogonDate, LockedOut, logonHours, LogonWorkstations, managedBy, Manager, modifyTimeStamp, Name, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, primaryGroupId, ProfilePath, SamAccountName, ScriptPath, SIDHistory, servicePrincipalName, TrustedForDelegation, TrustedToAuthForDelegation, UseDESKeyOnly, userAccountControl @adServerParameters
                Groups            = Get-ADGroup -Filter * -Properties adminCount, createTimeStamp, DistinguishedName, GroupCategory, GroupScope, isCriticalSystemObject, ManagedBy, modifyTimeStamp, SIDHistory @adServerParameters
                ServiceAccounts   = Get-ADServiceAccount -Filter * @adServerParameters
                DomainControllers = Get-ADDomainController -Filter * @adServerParameters
                ReplicationSites  = Get-ADReplicationSite -Filter * @adServerParameters
                Subnets           = Get-ADReplicationSubnet -Filter * -Properties * @adServerParameters
                RootDSE           = Get-ADRootDSE @adServerParameters | Select-Object *
                OptionalFeatures  = Get-ADOptionalFeature -Filter * -Properties * @adServerParameters
                CollectionTime    = Get-Date
            }

            if (-not $domainState.Domain) {
                throw "Failed to retrieve domain information from Active Directory. Verify connectivity and that the specified ComputerName is a valid domain controller."
            }
            if (-not $domainState.RootDSE) {
                throw "Failed to retrieve RootDSE information from Active Directory. Verify connectivity and that the specified ComputerName is a valid domain controller."
            }

            $resolvedComputerName = if ($ComputerName) { $ComputerName } else { $domainState.Domain.DNSRoot }

            # Collect Replication Connection information
            try {
                $replicationConnections = Get-ADReplicationConnection -Filter * -Properties * @adServerParameters
                $domainState['ReplicationConnections'] = $replicationConnections
            }
            catch {
                Write-Verbose "Could not collect Replication Connection data: $($_.Exception.Message)"
                $domainState['ReplicationConnections'] = @()
            }

            # Collect DFS-R Subscription information (for SYSVOL replication)
            try {
                $dfsrSubscriptions = Get-ADObject -Filter { objectClass -eq "msDFSR-Subscription" } -Properties * @adServerParameters
                $domainState['DfsrSubscriptions'] = $dfsrSubscriptions
            }
            catch {
                Write-Verbose "Could not collect DFS-R Subscription data: $($_.Exception.Message)"
                $domainState['DfsrSubscriptions'] = @()
            }

            # Collect Trust information
            try {
                $trusts = Get-ADTrust -Filter * -Properties * @adServerParameters
                $domainState['Trusts'] = $trusts
            }
            catch {
                Write-Verbose "Could not collect Trust data: $($_.Exception.Message)"
                $domainState['Trusts'] = @()
            }

            # Collect Organizational Units
            try {
                $organizationalUnits = Get-ADOrganizationalUnit -Filter * -Properties Name, DistinguishedName, whenCreated, whenChanged, modifyTimeStamp, createTimeStamp, ManagedBy, Description @adServerParameters
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
                $dnsZones = Get-DnsServerZone -ComputerName $resolvedComputerName -ErrorAction Stop | Select-Object *
                $domainState['DNSZones'] = $dnsZones

                # Collect DNS records for each zone (limit to essential record types for performance)
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
                Write-Verbose "DnsServer module not available. DNS data will not be collected."
                $domainState['DNSZones'] = @()
                $domainState['DNSRecords'] = @()
            }
            catch {
                Write-Verbose "Could not collect DNS data: $($_.Exception.Message)"
                $domainState['DNSZones'] = @()
                $domainState['DNSRecords'] = @()
            }

            # Collect Configuration container object tree
            try {
                $configurationContext = $domainState.RootDSE.ConfigurationNamingContext

                $configuration = @{}

                # WellKnown Security Principals
                try {
                    $wellKnownPath = "CN=WellKnown Security Principals,$configurationContext"
                    $configuration['WellKnownSecurityPrincipals'] = Get-ADObject -SearchBase $wellKnownPath -Filter * -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect WellKnownSecurityPrincipals data: $($_.Exception.Message)"
                    $configuration['WellKnownSecurityPrincipals'] = $null
                }

                # Site Links
                try {
                    $siteLinks = Get-ADReplicationSiteLink -Filter * -Properties * @adServerParameters
                    $configuration['SiteLinks'] = $siteLinks
                } catch {
                    Write-Verbose "Could not collect SiteLinks data: $($_.Exception.Message)"
                    $configuration['SiteLinks'] = $null
                }

                # DHCP Servers
                try {
                    $dhcpPath = "CN=NetServices,CN=Services,$configurationContext"
                    $configuration['DhcpServers'] = Get-ADObject -SearchBase $dhcpPath -Filter { objectClass -eq "dhcpClass" -or objectClass -eq "dhcpServer" -or objectClass -eq "serviceConnectionPoint" } -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect DhcpServers data: $($_.Exception.Message)"
                    $configuration['DhcpServers'] = $null
                }

                # AuthN Policy Containers
                try {
                    $authNPath = "CN=AuthN Policy Configuration,CN=Services,$configurationContext"
                    $configuration['AuthNPolicyContainers'] = Get-ADObject -SearchBase $authNPath -Filter * -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect AuthNPolicyContainers data: $($_.Exception.Message)"
                    $configuration['AuthNPolicyContainers'] = $null
                }

                # PKI / Certificate Services paths
                $pkiPath = "CN=Public Key Services,CN=Services,$configurationContext"

                # Trusted Root CAs
                try {
                    $rootCaPath = "CN=Certification Authorities,$pkiPath"
                    $configuration['TrustedRootCAs'] = Get-ADObject -SearchBase $rootCaPath -Filter { objectClass -eq "certificationAuthority" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect TrustedRootCAs data: $($_.Exception.Message)"
                    $configuration['TrustedRootCAs'] = $null
                }

                # Intermediate CAs (AIA container)
                try {
                    $aiaPath = "CN=AIA,$pkiPath"
                    $configuration['IntermediateCAs'] = Get-ADObject -SearchBase $aiaPath -Filter { objectClass -eq "certificationAuthority" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect IntermediateCAs data: $($_.Exception.Message)"
                    $configuration['IntermediateCAs'] = $null
                }

                # Enterprise CAs
                try {
                    $enrollmentPath = "CN=Enrollment Services,$pkiPath"
                    $configuration['EnterpriseCAs'] = Get-ADObject -SearchBase $enrollmentPath -Filter { objectClass -eq "pKIEnrollmentService" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect EnterpriseCAs data: $($_.Exception.Message)"
                    $configuration['EnterpriseCAs'] = $null
                }

                # Certificate Templates
                try {
                    $templatePath = "CN=Certificate Templates,$pkiPath"
                    $configuration['CertificateTemplates'] = Get-ADObject -SearchBase $templatePath -Filter { objectClass -eq "pKICertificateTemplate" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect CertificateTemplates data: $($_.Exception.Message)"
                    $configuration['CertificateTemplates'] = $null
                }

                # Enrollment Templates - derived from Enterprise CAs' published templates
                try {
                    $enrollmentTemplates = @()
                    $enterpriseCAs = $configuration['EnterpriseCAs']
                    if ($enterpriseCAs) {
                        foreach ($ca in $enterpriseCAs) {
                            if ($ca.certificateTemplates) {
                                $enrollmentTemplates += $ca.certificateTemplates
                            }
                        }
                    }
                    $configuration['EnrollmentTemplates'] = $enrollmentTemplates | Select-Object -Unique
                } catch {
                    Write-Verbose "Could not collect EnrollmentTemplates data: $($_.Exception.Message)"
                    $configuration['EnrollmentTemplates'] = $null
                }

                # CRL Distribution Points
                try {
                    $cdpPath = "CN=CDP,$pkiPath"
                    $configuration['CrlDistributionPoints'] = Get-ADObject -SearchBase $cdpPath -Filter { objectClass -eq "cRLDistributionPoint" -or objectClass -eq "certificationAuthority" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect CrlDistributionPoints data: $($_.Exception.Message)"
                    $configuration['CrlDistributionPoints'] = $null
                }

                # NTAuthCertificates
                try {
                    $ntAuthPath = "CN=NTAuthCertificates,$pkiPath"
                    $configuration['NtAuthCertificates'] = Get-ADObject -Identity $ntAuthPath -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect NtAuthCertificates data: $($_.Exception.Message)"
                    $configuration['NtAuthCertificates'] = $null
                }

                # LDAP Query Policies
                try {
                    $queryPolicyPath = "CN=Query Policies,CN=Directory Service,CN=Windows NT,CN=Services,$configurationContext"
                    $configuration['LdapQueryPolicies'] = Get-ADObject -SearchBase $queryPolicyPath -Filter { objectClass -eq "queryPolicy" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect LdapQueryPolicies data: $($_.Exception.Message)"
                    $configuration['LdapQueryPolicies'] = $null
                }

                # Directory Service settings (TombstoneLifetime, DsHeuristics, SpnMappings)
                try {
                    $dsPath = "CN=Directory Service,CN=Windows NT,CN=Services,$configurationContext"
                    $dsObject = Get-ADObject -Identity $dsPath -Properties tombstoneLifetime, dSHeuristics, sPNMappings @adServerParameters
                    $configuration['TombstoneLifetime'] = $dsObject.tombstoneLifetime
                    $configuration['DsHeuristics'] = $dsObject.dSHeuristics
                    $configuration['SpnMappings'] = $dsObject.sPNMappings
                } catch {
                    Write-Verbose "Could not collect Directory Service settings: $($_.Exception.Message)"
                    $configuration['TombstoneLifetime'] = $null
                    $configuration['DsHeuristics'] = $null
                    $configuration['SpnMappings'] = $null
                }

                # KDS Root Keys
                try {
                    $kdsPath = "CN=Master Root Keys,CN=Group Key Distribution,CN=Services,$configurationContext"
                    $configuration['KdsRootKeys'] = Get-ADObject -SearchBase $kdsPath -Filter { objectClass -eq "msKds-ProvRootKey" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect KdsRootKeys data: $($_.Exception.Message)"
                    $configuration['KdsRootKeys'] = $null
                }

                # Activation Objects
                try {
                    $activationPath = "CN=Activation Objects,CN=Services,$configurationContext"
                    $configuration['ActivationObjects'] = Get-ADObject -SearchBase $activationPath -Filter { objectClass -eq "msImaging-PSP" -or objectClass -eq "serviceConnectionPoint" } -SearchScope OneLevel -Properties * @adServerParameters
                } catch {
                    Write-Verbose "Could not collect ActivationObjects data: $($_.Exception.Message)"
                    $configuration['ActivationObjects'] = $null
                }

                $domainState['Configuration'] = [PSCustomObject]$configuration
            }
            catch {
                Write-Verbose "Could not collect Configuration container data: $($_.Exception.Message)"
                $domainState['Configuration'] = $null
            }

            # Collect Schema information
            try {
                $schemaContext = (Get-ADRootDSE @adServerParameters).schemaNamingContext
                $schemaObjects = Get-ADObject -SearchBase $schemaContext -Filter * -Properties whenCreated, objectClass @adServerParameters
                $domainState['SchemaObjects'] = $schemaObjects

                # Get schema version information from the schema container
                $schemaContainer = Get-ADObject -Identity $schemaContext -Properties objectVersion, whenCreated, whenChanged @adServerParameters
                $domainState['SchemaContainer'] = $schemaContainer
            }
            catch {
                Write-Verbose "Could not collect Schema data: $($_.Exception.Message)"
                $domainState['SchemaObjects'] = @()
                $domainState['SchemaContainer'] = $null
            }

            # Collect Printer information (published printers in AD)
            try {
                $printers = Get-ADObject -Filter { objectClass -eq "printQueue" } -Properties * @adServerParameters
                $domainState['Printers'] = $printers
            }
            catch {
                Write-Verbose "Could not collect Printer data: $($_.Exception.Message)"
                $domainState['Printers'] = @()
            }

            # Check LAPS installation status
            try {
                # Check for LAPS schema extensions (ms-Mcs-AdmPwd attribute)
                $lapsSchemaCheck = Get-ADObject -SearchBase $schemaContext -Filter { name -eq "ms-Mcs-AdmPwd" } -ErrorAction SilentlyContinue @adServerParameters
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
                if ($ComputerName) {
                    $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$ComputerName/$domainDN", $null, $null, ([System.DirectoryServices.AuthenticationTypes]::Secure -bor [System.DirectoryServices.AuthenticationTypes]::ServerBind))
                } else {
                    $searcher.SearchRoot = [ADSI]"LDAP://$domainDN"
                }
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
