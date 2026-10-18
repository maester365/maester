function Get-MtADGpoState {
    <#
    .SYNOPSIS
    Collects Active Directory Group Policy state information.

    .DESCRIPTION
    Collects GPO metadata, links, and permissions from Active Directory over LDAP.
    Results are cached for the session to avoid repeated queries.
    Connect-Maester -Service ActiveDirectory must complete successfully before this command can collect or return data.

    Each entry in GPOReports summarizes the GPO's DACL: PermissionsPresent (the DACL has at least one entry),
    HasAuthenticatedUsers, HasEnterpriseDomainControllers and HasDomainComputers (an access-allowed entry for
    that principal applies to the GPO) and HasInheritedPermissions (an entry is inherited from the parent
    container). These are $null when the security descriptor of the GPO was not returned.

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

    $resolvedDomain = [string]$__MtSession.ADConnection.ResolvedDomain
    $cacheKey = if ($resolvedDomain) { "GpoState:$resolvedDomain" } else { 'GpoState' }

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD GPO State data from Active Directory'

        $protocolConnection = $null
        try {
            $protocolTargetParameters = @{
                AuthMode             = $__MtSession.ADConnection.RequestedAuthMode
                TlsMode              = $__MtSession.ADConnection.RequestedTlsMode
                SkipCertificateCheck = [bool]$__MtSession.ADConnection.SkipCertificateCheck
                PassThru             = $true
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
            $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $protocolConnectionState
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
                    $rawFlags = $flags -band 3
                    $mappedStatus = switch ($rawFlags) {
                        0 { 3 }   # all enabled -> AllEnabled
                        1 { 1 }   # user disabled -> UserDisabled
                        2 { 2 }   # computer disabled -> ComputerDisabled
                        3 { 0 }   # all disabled -> AllDisabled
                    }
                    $gpo | Add-Member -NotePropertyName GpoStatus -NotePropertyValue $mappedStatus -Force
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
            $domainLinksFailed = $false
            $siteLinksFailed = $false
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
                $domainLinksFailed = $true
                $gpoState['LinkContainers'] = $null
                $gpoState['GPOLinks'] = $null
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
                $siteLinksFailed = $true
                $gpoState['SiteContainers'] = $null
            }
            if (-not $domainLinksFailed -and -not $siteLinksFailed) {
                $gpoState['GPOLinks'] = @($parsedGpoLinks)
            }

            try {
                $applyGroupPolicyGuid = 'edacfd8f-ffb3-11d1-b41d-00a0c968f939'
                $gpoReports = foreach ($gpo in $gpoState.GPOs) {
                    $gpoGuid = ([string]$gpo.Id).Trim('{}')
                    $gpoLinks = if ($null -ne $gpoState.GPOLinks) {
                        @($gpoState.GPOLinks | Where-Object { ([string]$_.GpoGuid).Trim('{}') -eq $gpoGuid })
                    } else { $null }
                $descriptor = $gpo.ntSecurityDescriptor
                if ($descriptor -is [byte[]]) {
                    $descriptor = ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $descriptor
                }

                $hasDenyAce = $null
                $hasApplyGroupPolicyAce = $null
                if ($null -ne $descriptor) {
                    $access = @($descriptor.Access)
                    $hasDenyAce = [bool]($access | Where-Object { $_.AccessControlType -eq 'Deny' } | Select-Object -First 1)
                    $hasApplyGroupPolicyAce = [bool]($access | Where-Object {
                            $_.AccessControlType -eq 'Allow' -and
                            (([string]$_.ObjectType -eq $applyGroupPolicyGuid) -or
                                ([string]$_.ActiveDirectoryRights -match 'ApplyGroupPolicy') -or
                                (([string]$_.ActiveDirectoryRights -match 'ExtendedRight') -and ([string]$_.ObjectType -eq $applyGroupPolicyGuid)))
                        } | Select-Object -First 1)
                }

                    # Permission summary of the DACL. $null means the security descriptor was not returned,
                    # so the permissions are unknown rather than absent.
                    $permissionsPresent = $null
                    $hasAuthenticatedUsers = $null
                    $hasEnterpriseDomainControllers = $null
                    $hasDomainComputers = $null
                    $hasInheritedPermissions = $null
                    if ($null -ne $descriptor -and $descriptor.PSObject.Properties['Access']) {
                        $aces = @($access | Where-Object { $null -ne $_ })
                        # An inherit-only ACE grants nothing on the GPO itself.
                        $allowedSids = @($aces | Where-Object { $_.AccessControlType -eq 'Allow' -and [string]$_.AceFlags -notmatch 'InheritOnly' } | ForEach-Object { [string]$_.Sid })
                        # A deny for a principal that is also allowed takes precedence, but how much of the
                        # allow it removes depends on the access masks of both entries, which this summary
                        # does not compare. That principal's access is unknown rather than present.
                        $deniedSids = @($aces | Where-Object { $_.AccessControlType -eq 'Deny' -and [string]$_.AceFlags -notmatch 'InheritOnly' } | ForEach-Object { [string]$_.Sid })
                        $permissionsPresent = $aces.Count -gt 0
                        $hasAuthenticatedUsers = if (($allowedSids -contains 'S-1-5-11') -and ($deniedSids -contains 'S-1-5-11')) { $null } else { $allowedSids -contains 'S-1-5-11' }
                        $hasEnterpriseDomainControllers = if (($allowedSids -contains 'S-1-5-9') -and ($deniedSids -contains 'S-1-5-9')) { $null } else { $allowedSids -contains 'S-1-5-9' }
                        # Domain Computers is RID 515 of a domain SID.
                        $domainComputers = '^S-1-5-21-\d+-\d+-\d+-515$'
                        $allowedComputers = @($allowedSids -match $domainComputers)
                        $deniedComputers = @($deniedSids -match $domainComputers)
                        # Only the same group being both allowed and denied is unknown: in a forest, one
                        # domain's Domain Computers being denied says nothing about another domain's.
                        $hasDomainComputers = if (@($allowedComputers | Where-Object { $deniedComputers -contains $_ }).Count -gt 0) { $null } else { $allowedComputers.Count -gt 0 }
                        $hasInheritedPermissions = [bool]($aces | Where-Object { $_.IsInherited } | Select-Object -First 1)
                    }

                    $hasVersionMismatch = $null
                    $cpasswordFound = $null
                    $defaultPasswordFound = $null
                    $errors = [System.Collections.Generic.List[object]]::new()
                    try {
                        Write-Verbose "Collecting SYSVOL content for GPO '$gpoGuid'"
                        $sysvolContent = Get-MtSysvolContent -Operation Connect -GpoGuid $gpoGuid
                        if ($null -ne $sysvolContent.GptIni -and $null -ne $sysvolContent.GptIni.Version) {
                            $hasVersionMismatch = [long]$gpo.VersionNumber -ne [long]$sysvolContent.GptIni.Version
                        }
                        $cpasswordFound = [bool]$sysvolContent.CpasswordFound
                        $defaultPasswordFound = [bool]$sysvolContent.DefaultPasswordFound
                    }
                    catch {
                        $errors.Add([PSCustomObject][ordered]@{
                                Transport = 'SYSVOL'
                                Message   = $_.Exception.Message
                            }) | Out-Null
                        Write-Verbose "Could not collect SYSVOL content for GPO '$gpoGuid': $($_.Exception.Message)"
                    }

                    $enforcementEnabled = if ($null -ne $gpoLinks) {
                        [bool]($gpoLinks | Where-Object { $_.IsEnforced } | Select-Object -First 1)
                    } else { $null }
                    [PSCustomObject][ordered]@{
                        GPOId                          = $gpo.Id
                        GPOName                        = $gpo.DisplayName
                        Name                           = $gpo.DisplayName
                        DisabledLinks                  = if ($null -ne $gpoLinks) { @($gpoLinks | Where-Object { $_.IsDisabled }).Count } else { $null }
                        HasVersionMismatch             = $hasVersionMismatch
                        CpasswordFound                 = $cpasswordFound
                        DefaultPasswordFound           = $defaultPasswordFound
                        HasApplyGroupPolicyAce         = $hasApplyGroupPolicyAce
                        HasDenyAce                     = $hasDenyAce
                        PermissionsPresent             = $permissionsPresent
                        HasAuthenticatedUsers          = $hasAuthenticatedUsers
                        HasEnterpriseDomainControllers = $hasEnterpriseDomainControllers
                        HasDomainComputers             = $hasDomainComputers
                        HasInheritedPermissions        = $hasInheritedPermissions
                        EnforcementEnabled             = $enforcementEnabled
                        Enforcement                    = $enforcementEnabled
                        Errors                         = @($errors)
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
