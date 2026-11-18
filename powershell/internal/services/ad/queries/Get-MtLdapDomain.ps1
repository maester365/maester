function Get-MtLdapDomain {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    function ConvertFrom-DomainDistinguishedName {
        param([string] $DistinguishedName)

        return (([regex]::Matches($DistinguishedName, '(?i)(?:^|,)DC=([^,]+)') | ForEach-Object { $_.Groups[1].Value }) -join '.')
    }

    function Resolve-FsmoOwner {
        param([string] $OwnerDistinguishedName)

        if ([string]::IsNullOrWhiteSpace($OwnerDistinguishedName)) { return $null }
        try {
            $serverDn = $OwnerDistinguishedName -replace '^CN=NTDS Settings,', ''
            $server = Invoke-MtLdapSearch -Connection $Connection -SearchBase $serverDn -Scope Base -Filter '(objectClass=server)' -Attributes @('dNSHostName') -PageSize 0 | Select-Object -First 1
            if (-not [string]::IsNullOrWhiteSpace($server.dNSHostName)) { return [string]$server.dNSHostName }
        }
        catch {
            Write-Verbose "Could not resolve FSMO owner '$OwnerDistinguishedName': $($_.Exception.Message)"
        }

        return $OwnerDistinguishedName
    }

    try {
        $rootDse = Get-MtLdapRootDse -Connection $Connection
        if ([string]::IsNullOrWhiteSpace($SearchBase)) {
            $SearchBase = $rootDse.DefaultNamingContext
        }

        $attributes = @('distinguishedName', 'name', 'objectSid', 'lockoutDuration', 'lockoutThreshold', 'lockOutObservationWindow', 'maxPwdAge', 'minPwdAge', 'minPwdLength', 'ms-DS-MachineAccountQuota', 'pwdProperties', 'pwdHistoryLength', 'objectVersion', 'whenCreated', 'whenChanged', 'msDS-Behavior-Version', 'fSMORoleOwner', 'msDS-AllowedDNSSuffixes', 'msDS-LogonTimeSyncInterval')
        $entry = Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Base -Filter '(objectClass=domainDNS)' -Attributes $attributes -PageSize 0 | Select-Object -First 1
        if ($null -eq $entry) {
            return $null
        }

        $crossRefs = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Partitions,$($rootDse.ConfigurationNamingContext)" -Scope OneLevel -Filter '(objectClass=crossRef)' -Attributes @('nCName', 'nETBIOSName') -PageSize 0)
        $crossRef = $crossRefs | Where-Object { $_.nCName -eq $SearchBase } | Select-Object -First 1

        $infrastructure = Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Infrastructure,$SearchBase" -Scope Base -Filter '(objectClass=infrastructureUpdate)' -Attributes @('fSMORoleOwner') -PageSize 0 | Select-Object -First 1
        $ridManager = Invoke-MtLdapSearch -Connection $Connection -SearchBase ('CN=RID Manager$,CN=System,' + $SearchBase) -Scope Base -Filter '(objectClass=rIDManager)' -Attributes @('fSMORoleOwner', 'rIDAvailablePool') -PageSize 0 | Select-Object -First 1
        $domainModeNames = @('Windows2000Domain', 'Windows2003InterimDomain', 'Windows2003Domain', 'Windows2008Domain', 'Windows2008R2Domain', 'Windows2012Domain', 'Windows2012R2Domain', 'Windows2016Domain')
        $domainModeValue = if ($null -ne $entry.'msDS-Behavior-Version') { [int]$entry.'msDS-Behavior-Version' } else { $null }

        return [PSCustomObject]@{
            DistinguishedName       = [string]$entry.DistinguishedName
            Name                    = [string]$entry.name
            ObjectSid               = $entry.objectSid
            DomainSID               = $entry.objectSid
            LockoutDuration         = $entry.lockoutDuration
            LockoutThreshold        = $entry.lockoutThreshold
            LockoutObservationWindow = $entry.lockOutObservationWindow
            MaxPwdAge               = $entry.maxPwdAge
            MinPwdAge               = $entry.minPwdAge
            MinPwdLength            = $entry.minPwdLength
            MsDsMachineAccountQuota = $entry.'ms-DS-MachineAccountQuota'
            PwdProperties           = $entry.pwdProperties
            ComplexityEnabled       = if ($null -ne $entry.pwdProperties) { ([int]$entry.pwdProperties -band 1) -ne 0 } else { $null }
            ReversibleEncryptionEnabled = if ($null -ne $entry.pwdProperties) { ([int]$entry.pwdProperties -band 16) -ne 0 } else { $null }
            PasswordExpirationDisabled = if ($null -ne $entry.maxPwdAge) { $entry.maxPwdAge -eq [timespan]::Zero } else { $null }
            LockoutRequiresAdminUnlock = if ($null -ne $entry.lockoutDuration) { $entry.lockoutDuration -eq [timespan]::Zero } else { $null }
            PwdHistoryLength        = $entry.pwdHistoryLength
            RIDAvailablePool        = $ridManager.rIDAvailablePool
            ObjectVersion           = $entry.objectVersion
            WhenCreated             = $entry.whenCreated
            WhenChanged             = $entry.whenChanged
            DnsRoot                 = ConvertFrom-DomainDistinguishedName -DistinguishedName $SearchBase
            Forest                  = ConvertFrom-DomainDistinguishedName -DistinguishedName $rootDse.RootDomainNamingContext
            DomainMode              = if ($domainModeValue -eq 10) { 'Windows2025Domain' } elseif ($null -ne $domainModeValue -and $domainModeValue -ge 0 -and $domainModeValue -lt $domainModeNames.Count) { $domainModeNames[$domainModeValue] } else { $domainModeValue }
            DomainLevelValue        = $domainModeValue
            PdcOwnerDistinguishedName = [string]$entry.fSMORoleOwner
            RidOwnerDistinguishedName = [string]$ridManager.fSMORoleOwner
            InfrastructureOwnerDistinguishedName = [string]$infrastructure.fSMORoleOwner
            LogonTimeSyncIntervalDays = $entry.'msDS-LogonTimeSyncInterval'
            InfrastructureMaster    = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$infrastructure.fSMORoleOwner)
            PDCEmulator             = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$entry.fSMORoleOwner)
            RIDMaster               = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$ridManager.fSMORoleOwner)
            NetBIOSName             = [string]$crossRef.nETBIOSName
            AllowedDnsSuffixes      = [string[]]@(@($entry.'msDS-AllowedDNSSuffixes') | Where-Object { $null -ne $_ })
        }
    }
    catch {
        Write-Verbose "Could not query the LDAP domain object: $($_.Exception.Message)"
        return $null
    }
}
