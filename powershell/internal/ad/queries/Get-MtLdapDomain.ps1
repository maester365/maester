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

        $attributes = @('distinguishedName', 'name', 'objectSid', 'lockoutDuration', 'lockoutThreshold', 'maxPwdAge', 'minPwdAge', 'minPwdLength', 'ms-DS-MachineAccountQuota', 'pwdProperties', 'pwdHistoryLength', 'rIDAvailablePool', 'objectVersion', 'whenCreated', 'whenChanged', 'msDS-Behavior-Version', 'fSMORoleOwner')
        $entry = Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Base -Filter '(objectClass=domainDNS)' -Attributes $attributes -PageSize 0 | Select-Object -First 1
        if ($null -eq $entry) {
            return $null
        }

        $infrastructure = Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Infrastructure,$SearchBase" -Scope Base -Filter '(objectClass=infrastructureUpdate)' -Attributes @('fSMORoleOwner') -PageSize 0 | Select-Object -First 1
        $ridManager = Invoke-MtLdapSearch -Connection $Connection -SearchBase ('CN=RID Manager$,CN=System,' + $SearchBase) -Scope Base -Filter '(objectClass=rIDManager)' -Attributes @('fSMORoleOwner') -PageSize 0 | Select-Object -First 1
        $domainModeNames = @('Windows2000Domain', 'Windows2003InterimDomain', 'Windows2003Domain', 'Windows2008Domain', 'Windows2008R2Domain', 'Windows2012Domain', 'Windows2012R2Domain', 'Windows2016Domain')
        $domainModeValue = [int]$entry.'msDS-Behavior-Version'

        return [PSCustomObject]@{
            DistinguishedName       = [string]$entry.DistinguishedName
            Name                    = [string]$entry.name
            ObjectSid               = $entry.objectSid
            DomainSID               = $entry.objectSid
            LockoutDuration         = $entry.lockoutDuration
            LockoutThreshold        = $entry.lockoutThreshold
            MaxPwdAge               = $entry.maxPwdAge
            MinPwdAge               = $entry.minPwdAge
            MinPwdLength            = $entry.minPwdLength
            MsDsMachineAccountQuota = $entry.'ms-DS-MachineAccountQuota'
            PwdProperties           = $entry.pwdProperties
            PwdHistoryLength        = $entry.pwdHistoryLength
            RIDAvailablePool        = $entry.rIDAvailablePool
            ObjectVersion           = $entry.objectVersion
            WhenCreated             = $entry.whenCreated
            WhenChanged             = $entry.whenChanged
            DnsRoot                 = ConvertFrom-DomainDistinguishedName -DistinguishedName $SearchBase
            Forest                  = ConvertFrom-DomainDistinguishedName -DistinguishedName $rootDse.RootDomainNamingContext
            DomainMode              = if ($domainModeValue -ge 0 -and $domainModeValue -lt $domainModeNames.Count) { $domainModeNames[$domainModeValue] } else { $domainModeValue }
            InfrastructureMaster    = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$infrastructure.fSMORoleOwner)
            PDCEmulator             = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$entry.fSMORoleOwner)
            RIDMaster               = Resolve-FsmoOwner -OwnerDistinguishedName ([string]$ridManager.fSMORoleOwner)
        }
    }
    catch {
        Write-Verbose "Could not query the LDAP domain object: $($_.Exception.Message)"
        return $null
    }
}
