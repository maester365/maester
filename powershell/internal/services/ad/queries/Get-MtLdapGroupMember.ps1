function Get-MtLdapGroupMember {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $GroupDistinguishedName,

        [switch] $SkipMemoization
    )

    function ConvertTo-SidFilterValue {
        param([object] $Sid)

        $sidValue = if ($Sid.PSObject.Properties['Value']) { [string]$Sid.Value } else { [string]$Sid }
        $parts = $sidValue -split '-'
        if ($parts.Count -lt 4 -or $parts[0] -ne 'S') { return $null }
        $bytes = [System.Collections.Generic.List[byte]]::new()
        $bytes.Add([byte]$parts[1])
        $bytes.Add([byte]($parts.Count - 3))
        $authority = [uint64]$parts[2]
        for ($shift = 40; $shift -ge 0; $shift -= 8) { $bytes.Add([byte](($authority -shr $shift) -band 0xff)) }
        for ($index = 3; $index -lt $parts.Count; $index++) { $bytes.AddRange([BitConverter]::GetBytes([uint32]$parts[$index])) }
        return (($bytes | ForEach-Object { '\{0:x2}' -f $_ }) -join '')
    }

    try {
        if ($null -eq $script:__MtLdapGroupMemberCache) { $script:__MtLdapGroupMemberCache = @{} }
        $hostProperty = $Connection.SessionOptions.PSObject.Properties['Host']
        $hostName = if ($null -ne $hostProperty -and -not [string]::IsNullOrWhiteSpace([string]$hostProperty.Value)) {
            [string]$hostProperty.Value
        }
        elseif ($Connection.Directory.Servers.Count -gt 0) {
            [string]$Connection.Directory.Servers[0]
        }
        else {
            [string]$Connection.SessionOptions.HostName
        }
        $cacheKey = "$hostName`:$GroupDistinguishedName"
        if (-not $SkipMemoization -and $script:__MtLdapGroupMemberCache.ContainsKey($cacheKey)) {
            return @($script:__MtLdapGroupMemberCache[$cacheKey])
        }

        $members = [System.Collections.Generic.List[object]]::new()
        foreach ($memberDn in @(Get-MtLdapRangedValue -Connection $Connection -DistinguishedName $GroupDistinguishedName -AttributeName 'member')) {
            $isForeign = [string]$memberDn -imatch '(^|,)CN=ForeignSecurityPrincipals,'
            $resolvedDn = [string]$memberDn
            $sid = $null
            $member = Invoke-MtLdapSearch -Connection $Connection -SearchBase ([string]$memberDn) -Scope Base -Filter '(objectClass=*)' -Attributes @('distinguishedName', 'name', 'objectClass', 'objectSid') -PageSize 0 | Select-Object -First 1
            if ($null -ne $member) { $sid = $member.objectSid }

            if ($isForeign -and $null -ne $sid) {
                $rootDse = Get-MtLdapRootDse -Connection $Connection
                $sidFilter = ConvertTo-SidFilterValue -Sid $sid
                $resolved = if ($null -ne $sidFilter) { Invoke-MtLdapSearch -Connection $Connection -SearchBase $rootDse.DefaultNamingContext -Scope Subtree -Filter "(objectSid=$sidFilter)" -Attributes @('distinguishedName', 'name', 'objectClass', 'objectSid') | Where-Object { $_.DistinguishedName -ne $memberDn } | Select-Object -First 1 } else { $null }
                if ($null -ne $resolved) {
                    $member = $resolved
                    $resolvedDn = [string]$resolved.DistinguishedName
                    $sid = $resolved.objectSid
                }
            }

            $members.Add([PSCustomObject]@{
                    DistinguishedName         = $resolvedDn
                    Name                      = [string]$member.Name
                    ObjectClass               = @($member.ObjectClass)[-1]
                    Sid                       = $sid
                    IsForeignSecurityPrincipal = $isForeign
                }) | Out-Null
        }

        $result = @($members)
        if (-not $SkipMemoization) { $script:__MtLdapGroupMemberCache[$cacheKey] = $result }
        return $result
    }
    catch {
        Write-Verbose "Could not query LDAP members for '$GroupDistinguishedName': $($_.Exception.Message)"
        return @()
    }
}
