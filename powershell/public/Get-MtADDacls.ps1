function Get-MtADDacls {
    <#
    .SYNOPSIS
    Collects Active Directory ACLs (Access Control Lists).

    .DESCRIPTION
    Collects ACLs from AD objects including domains, OUs, GPOs, users, computers, and groups.
    Results are cached for the session to avoid repeated queries.
    Connect-Maester -Service ActiveDirectory must complete successfully before this command can collect or return data.

    .PARAMETER DnBase
    The distinguished name base(s) to search. Defaults to the domain root.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADDacls

    Returns cached DACLs or collects if not already cached. Returns no data unless Active Directory was explicitly connected through Connect-Maester.

    .EXAMPLE
    Get-MtADDacls -Refresh

    Forces a fresh collection of ACL data from Active Directory.

    .EXAMPLE
    Get-MtADDacls -DnBase "OU=Users,DC=contoso,DC=com"

    Collects ACLs only from the specified OU.

    .LINK
    https://maester.dev/docs/commands/Get-MtADDacls
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using Details')]
    [CmdletBinding()]
    param(
        [string[]]$DnBase,
        [switch]$Refresh
    )

    if (-not (Test-MtConnection -Service ActiveDirectory)) {
        Write-Verbose 'Active Directory is not connected. Run Connect-Maester -Service ActiveDirectory before collecting ACLs.'
        return $null
    }

    if (-not $__MtSession.ADConnection.ProtocolValidated) {
        Write-Verbose 'Active Directory ACL enrichment requires a protocol-validated Connect-Maester session.'
        return $null
    }

    $cacheKey = 'Dacls'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD ACLs from Active Directory'

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

            if (-not $DnBase) {
                $DnBase = @($protocolRootDse.DefaultNamingContext)
            }

            $dacls = @()

            foreach ($base in $DnBase) {
                Write-Verbose "Searching DN base: $base"
                $baseDacls = @(Get-MtLdapDacl -Connection $protocolConnection -SearchBase $base)
                Write-Verbose "Found $($baseDacls.Count) ACL entries in $base"
                $dacls += $baseDacls
            }

            $__MtSession.ADCache[$cacheKey] = $dacls
            $__MtSession.ADCollectionTime = Get-Date

            Write-Verbose "Successfully collected $($dacls.Count) ACL entries"
        }
        catch {
            Write-Error "Failed to collect AD ACLs: $($_.Exception.Message)"
            return $null
        }
        finally {
            if ($null -ne $protocolConnection) {
                $protocolConnection.Dispose()
            }
        }
    }
    else {
        Write-Verbose 'Using cached AD ACL data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
