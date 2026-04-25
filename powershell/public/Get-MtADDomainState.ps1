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
                Users             = Get-ADUser -Filter * -Properties adminCount, CannotChangePassword, createTimeStamp, DistinguishedName, Enabled, isCriticalSystemObject, LastBadPasswordAttempt, LastLogonDate, LockedOut, logonHours, LogonWorkstations, managedBy, modifyTimeStamp, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, SIDHistory, servicePrincipalName
                Groups            = Get-ADGroup -Filter * -Properties adminCount, createTimeStamp, DistinguishedName, GroupCategory, GroupScope, isCriticalSystemObject, ManagedBy, modifyTimeStamp, SIDHistory
                ServiceAccounts   = Get-ADServiceAccount -Filter *
                DomainControllers = Get-ADDomainController -Filter *
                ReplicationSites  = Get-ADReplicationSite -Filter *
                RootDSE           = Get-ADRootDSE | Select-Object *
                OptionalFeatures  = Get-ADOptionalFeature -Filter * -Properties *
                CollectionTime    = Get-Date
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
            }

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
