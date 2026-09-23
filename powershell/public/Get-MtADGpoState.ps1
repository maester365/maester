function Get-MtADGpoState {
    <#
    .SYNOPSIS
    Collects Active Directory Group Policy state information.

    .DESCRIPTION
    Collects GPO metadata, links, and permissions from Active Directory over LDAP.
    Results are cached for the session to avoid repeated queries.
    Connect-Maester -Service ActiveDirectory must complete successfully before this command can collect or return data.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADGpoState

    Returns cached GPO state or collects if not already cached. Returns no data unless Active Directory was explicitly connected through Connect-Maester.

    .EXAMPLE
    Get-MtADGpoState -Refresh

    Forces a fresh collection of GPO state data from Active Directory.

    .LINK
    https://maester.dev/docs/commands/Get-MtADGpoState
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )

    if (-not (Test-MtConnection -Service ActiveDirectory)) {
        Write-Verbose 'Active Directory is not connected. Run Connect-Maester -Service ActiveDirectory before collecting Group Policy state.'
        return $null
    }

    if (-not $__MtSession.ADConnection.ProtocolValidated) {
        Write-Verbose 'Active Directory GPO collection requires a protocol-validated Connect-Maester session.'
        return $null
    }

    $cacheKey = 'GpoState'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD GPO State data from Active Directory'

        $protocolConnection = $null
        try {
            $protocolTargetParameters = @{
                AuthMode = $__MtSession.ADConnection.RequestedAuthMode
                TlsMode  = $__MtSession.ADConnection.RequestedTlsMode
                PassThru = $true
            }
            if ($__MtSession.ADConnection.RequestedServer) {
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
            $gpoState = [ordered]@{
                GPOs           = @()
                CollectionTime = Get-Date
                GPOReports     = @()
                GPOLinks       = @()
                SiteContainers = @()
                LinkContainers = @()
            }

            try {
                $gpos = @(Get-MtLdapGpo -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                foreach ($gpo in $gpos) {
                    $flags = [int]$gpo.Flags
                    $gpo | Add-Member -NotePropertyName GpoStatus -NotePropertyValue ($flags -band 3) -Force
                    $gpo | Add-Member -NotePropertyName CreationTime -NotePropertyValue $gpo.Created -Force
                    $gpo | Add-Member -NotePropertyName ModificationTime -NotePropertyValue $gpo.Modified -Force
                }
                $gpoState['GPOs'] = $gpos
                Write-Verbose "Collected $($gpos.Count) GPOs"
            }
            catch {
                Write-Verbose "Could not collect GPO metadata: $($_.Exception.Message)"
            }

            $parsedGpoLinks = [System.Collections.Generic.List[object]]::new()
            try {
                $linkContainers = @(Get-MtLdapGpoLink -Connection $protocolConnection -SearchBase $protocolRootDse.DefaultNamingContext)
                $gpoState['LinkContainers'] = $linkContainers
                foreach ($container in $linkContainers) {
                    foreach ($linkMatch in [regex]::Matches([string]$container.GpLink, '\[(?<target>[^\]]+);\s*(?<options>\d+)\s*\]')) {
                        $guidMatch = [regex]::Match($linkMatch.Groups['target'].Value, '(?i)\{?(?<guid>[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})\}?')
                        if (-not $guidMatch.Success) {
                            Write-Verbose "Ignoring malformed GPO link on $($container.DistinguishedName): $($linkMatch.Value)"
                            continue
                        }

                        $options = [int]$linkMatch.Groups['options'].Value
                        $isDisabled = [bool]($options -band 1)
                        $isEnforced = [bool]($options -band 2)
                        $parsedGpoLinks.Add([PSCustomObject]@{
                                DistinguishedName = $container.DistinguishedName
                                ObjectClass        = @($container.ObjectClass)[-1]
                                GpoGuid            = [guid]$guidMatch.Groups['guid'].Value
                                Options            = $options
                                IsDisabled         = $isDisabled
                                IsEnforced         = $isEnforced
                                GpLink             = $linkMatch.Value
                                Enforced           = $isEnforced
                            }) | Out-Null
                    }
                }
                Write-Verbose "Collected GPO links from $($linkContainers.Count) domain and OU containers"
            }
            catch {
                Write-Verbose "Could not collect domain and OU GPO links: $($_.Exception.Message)"
            }

            try {
                $siteContainers = @(Get-MtLdapSiteContainer -Connection $protocolConnection -ConfigurationNamingContext $protocolRootDse.ConfigurationNamingContext)
                $gpoState['SiteContainers'] = $siteContainers
                foreach ($container in $siteContainers) {
                    foreach ($linkMatch in [regex]::Matches([string]$container.GpLink, '\[(?<target>[^\]]+);\s*(?<options>\d+)\s*\]')) {
                        $guidMatch = [regex]::Match($linkMatch.Groups['target'].Value, '(?i)\{?(?<guid>[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})\}?')
                        if (-not $guidMatch.Success) {
                            Write-Verbose "Ignoring malformed site GPO link on $($container.DistinguishedName): $($linkMatch.Value)"
                            continue
                        }

                        $options = [int]$linkMatch.Groups['options'].Value
                        $isDisabled = [bool]($options -band 1)
                        $isEnforced = [bool]($options -band 2)
                        $parsedGpoLinks.Add([PSCustomObject]@{
                                DistinguishedName = $container.DistinguishedName
                                ObjectClass        = @($container.ObjectClass)[-1]
                                GpoGuid            = [guid]$guidMatch.Groups['guid'].Value
                                Options            = $options
                                IsDisabled         = $isDisabled
                                IsEnforced         = $isEnforced
                                GpLink             = $linkMatch.Value
                                Enforced           = $isEnforced
                            }) | Out-Null
                    }
                }
                Write-Verbose "Collected GPO links from $($siteContainers.Count) site containers"
            }
            catch {
                Write-Verbose "Could not collect site GPO links: $($_.Exception.Message)"
            }
            $gpoState['GPOLinks'] = @($parsedGpoLinks)

            try {
                $applyGroupPolicyGuid = 'edacfd8f-ffb3-11d1-b41d-00a0c968f939'
                $gpoReports = foreach ($gpo in $gpoState.GPOs) {
                    $gpoGuid = ([string]$gpo.Id).Trim('{}')
                    $gpoLinks = @($gpoState.GPOLinks | Where-Object { ([string]$_.GpoGuid).Trim('{}') -eq $gpoGuid })
                    $descriptor = $gpo.ntSecurityDescriptor
                    if ($descriptor -is [byte[]]) {
                        $descriptor = ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor
                    }
                    $access = @($descriptor.Access)
                    $hasDenyAce = [bool]($access | Where-Object { $_.AccessControlType -eq 'Deny' } | Select-Object -First 1)
                    $hasApplyGroupPolicyAce = [bool]($access | Where-Object {
                            $_.AccessControlType -eq 'Allow' -and
                            (([string]$_.ObjectType -eq $applyGroupPolicyGuid) -or
                                ([string]$_.ActiveDirectoryRights -match 'ApplyGroupPolicy') -or
                                (([string]$_.ActiveDirectoryRights -match 'ExtendedRight') -and ([string]$_.ObjectType -eq $applyGroupPolicyGuid)))
                        } | Select-Object -First 1)

                    [PSCustomObject]@{
                        GPOId                  = $gpo.Id
                        GPOName                = $gpo.DisplayName
                        DisabledLinks          = @($gpoLinks | Where-Object { $_.IsDisabled }).Count
                        HasVersionMismatch     = $false
                        CpasswordFound         = $false
                        DefaultPasswordFound   = $false
                        HasApplyGroupPolicyAce = $hasApplyGroupPolicyAce
                        HasDenyAce             = $hasDenyAce
                        EnforcementEnabled     = [bool]($gpoLinks | Where-Object { $_.IsEnforced } | Select-Object -First 1)
                    }
                }
                $gpoState['GPOReports'] = @($gpoReports)
                Write-Verbose "Collected $($gpoState.GPOReports.Count) GPO reports"
            }
            catch {
                Write-Verbose "Could not build GPO reports: $($_.Exception.Message)"
                $gpoState['GPOReports'] = @()
            }

            $__MtSession.ADCache[$cacheKey] = $gpoState
            Write-Verbose "Successfully collected AD GPO State data at $($gpoState.CollectionTime)"
        }
        catch {
            Write-Error "Failed to collect AD GPO State data: $($_.Exception.Message)"
            return $null
        }
        finally {
            if ($null -ne $protocolConnection) {
                $protocolConnection.Dispose()
            }
        }
    }
    else {
        Write-Verbose 'Using cached AD GPO State data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
