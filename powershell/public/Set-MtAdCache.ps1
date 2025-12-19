<#
.SYNOPSIS
    Sets the local cache of AD lookups.

.DESCRIPTION
    By default all AD queries are cached and re-used for the duration of the session.

    Use this function to set the cache.

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.PARAMETER Objects
    Specific type of AD objects to query.

.EXAMPLE
    Set-MtAdCache

    This example sets the cache of AD queries.

.LINK
    https://maester.dev/docs/commands/Set-MtAdCache
#>
function Set-MtAdCache {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal function')]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential,
        [ValidateSet('All', 'Computers', 'Domains', 'Forest')]
        [string[]]$Objects = 'All'
    )

    if($Server){
        $PSDefaultParameterValues.Add("Get-Ad*:Server",$Server)
    }

    if($Credential){
        $PSDefaultParameterValues.Add("Get-Ad*:Credential",$Credential)
    }

    $primaryGroupIds = @(515,516,521)
    $dcPrimaryGroupIds = @(516,521)

    $rootDse = try{
        Write-Verbose "Attempting Get-AdRootDSE"
        Get-AdRootDSE
    }catch{
        Write-Error $_
        return $null
    }

    $configurationNamingContext = $rootDse.configurationNamingContext
    $ADObjectDirectoryService = @{
        Identity   = "CN=Directory Service,CN=Windows NT,CN=Services,$configurationNamingContext"
        Properties = "*"
    }
    $directoryService = try{
        Write-Verbose "Attempting query for Directory Service object"
        Get-ADObject @ADObjectDirectoryService
    }catch{
        Write-Error $_
        return $null
    }

    $HostSpnAlias = (($directoryService).spnmappings | Where-Object {
        $_ -like "host=*"
    }) -replace "host=" -split ","

    $Thresholds = @{
        DormantThresholdInDays = 90
        DormantDate            = $null
        ExpiredThresholdInDays = 180
        ExpiredDate            = $null
        StaleThresholdInDays   = 30
        StaleDate              = $null
    }
    $Thresholds.DormantDate = ((Get-Date).AddDays(-$Thresholds.DormantThresholdInDays)).Date
    $Thresholds.ExpiredDate = ((Get-Date).AddDays(-$Thresholds.ExpiredThresholdInDays)).Date
    $Thresholds.StaleDate   = ((Get-Date).AddDays(-$Thresholds.StaleThresholdInDays)).Date

    $__MtSession.AdCache = @{
        RootDSE                        = $rootDse
        ConfigurationNamingContext     = $configurationNamingContext
        DirectoryServiceConfigObj      = $directoryService
        Thresholds                     = $Thresholds
        HostSpnAlias                   = @($HostSpnAlias)
        PrimaryGroupIds                = $primaryGroupIds
        DomainControllerPgids          = $dcPrimaryGroupIds
        AdComputers                    = $__MtSession.AdCache.AdComputers
        AdDomains                      = $__MtSession.AdCache.AdDomains
        AdForest                       = $__MtSession.AdCache.AdForest
    }


    <#
    if($Objects -contains "Domains" -or $Objects -contains "All"){
        $domainControllers = @()
        $domainControllersSplat = @{
                SearchBase = $d.DomainControllersContainer
                Server     = $domain
                LDAPFilter = "objectClass=Computer"
                Properties = "*"
            }
            $dcs = try{
                Write-Verbose "Attempting AD query for DCs in $domain"
                Get-ADObject @domainControllersSplat
            }catch{
                Write-Error $_
                return $null
            }
            $domainControllers += @{
                Domain            = $d.Name
                DomainControllers = $dcs
            }
        }
        $__MtSession.AdCache.AdDomainControllers = @{
            SetFlag           = $true
            DomainControllers = @($domainControllers) # TODO Process this
            Data              = @{}
        }
        foreach ($domain in $__MtSession.AdCache.AdDomainControllers.Domains){
            $__MtSession.AdCache.AdDomains.Add("Data-$($domain.Name)",$__MtSession.AdCache.AdDomains.Data)
        }
    }

                #DeletedObjectsContainer            = $null
                #ForeignSecurityPrincipalsContainer = $null
                #LinkedGroupPolicyObjects           = $null
                #LostAndFoundContainer              = $null
                #QuotasContainer                    = $null
                #SystemsContainer                   = $null
    #>

    if($Objects -contains "Domains" -or $Objects -contains "All"){
        $forest = try{
            Write-Verbose "Attempting AD query for Forest"
            Get-ADForest
        }catch{
            Write-Error $_
            return $null
        }

        $domains = @()
        $domainObjects = @()
        foreach ($domain in $forest.Domains){
            $d = try{
                Write-Verbose "Attempting AD query for $domain"
                Get-ADDomain -Server $domain
            }catch{
                Write-Error $_
                return $null
            }

            $do = try{
                Write-Verbose "Attempting AD query for $domain object"
                Get-ADObject -Identity $domain.DistinguishedName -Properties *
            }catch{
                Write-Error $_
                return $null
            }

            $domains += $d
            $domainObjects += $do
        }

        $__MtSession.AdCache.AdDomains = @{
            SetFlag           = $true
            Domains           = @($domains)
            DomainObjects     = @($domainObjects)
            Data              = @{
                Name                               = $null
                NetBIOSName                        = $null
                IsNetBIOSNameCompliant             = $null
                DistinguishedName                  = $null
                DNSRoot                            = $null
                IsDNSRootCompliant                 = $null
                DomainFunctionalLevel              = $null
                AllowedDNSSuffixes                 = @()
                AllowedDNSSuffixesCount            = $null
                InfrastructureMaster               = $null
                PDCEmulator                        = $null
                RIDMaster                          = $null
                CommonFsmo                         = $null
                ChildDomains                       = @()
                ChildDomainsCount                  = $null
                ComputersContainer                 = $null
                DefaultComputersContainer          = $null
                DomainControllersContainer         = $null
                DefaultDomainControllersContainer  = $null
                UsersContainer                     = $null
                DefaultUsersContainer              = $null
                ReadOnlyDomainControllers          = @()
                ReadOnlyDomainControllersCount     = $null
                DomainControllers                  = @()
                DomainControllersCount             = $null
                PublicKeyRequiredPasswordRolling   = $null
                ManagedBy                          = $null
                IsSetManagedBy                     = $null
                ParentDomain                       = $null
                IsRootDomain                       = $null
                MachineAccountQuota                = $null
                IsDefaultMachineAccountQuota       = $null
                ForceLogoff                        = $null
                LockoutDuration                    = $null
                LockOutObservationWindow           = $null
                LockoutThreshold                   = $null
                MaxPwdAge                          = $null
                MinPwdAge                          = $null
                MinPwdLength                       = $null
                PwdHistoryLength                   = $null
                IsDefaultForceLogoff               = $null
                IsDefaultLockoutDuration           = $null
                IsDefaultLockOutObservationWindow  = $null
                IsDefaultLockoutThreshold          = $null
                IsDefaultMaxPwdAge                 = $null
                IsDefaultMinPwdAge                 = $null
                IsDefaultMinPwdLength              = $null
                IsDefaultPwdHistoryLength          = $null
                IsDefaultPasswordPolicy            = $null
            }
        }

        foreach ($domain in $__MtSession.AdCache.AdDomains.Domains){
            $__MtSession.AdCache.AdDomains.Add("Data-$($domain.Name)",$__MtSession.AdCache.AdDomains.Data)
        }
    }

    if($Objects -contains "Forest" -or $Objects -contains "All"){
        $forest = try{
            Write-Verbose "Attempting AD query for Forest"
            Get-ADForest
        }catch{
            Write-Error $_
            return $null
        }

        $__MtSession.AdCache.AdForest = @{
            SetFlag   = $true
            Forest    = @($forest)
            Data      = @{
                FunctionalLevel            = $rootDse.forestFunctionality
                CrossForestReferences      = @()
                CrossForestReferencesCount = $null
                DomainNamingMaster         = $null
                SchemaMaster               = $null
                CommonFsmo                 = $null
                Sites                      = @()
                SitesCount                 = $null
                DefaultSite                = $null
                Domains                    = @()
                DomainsCount               = $null
                UpnSuffixes                = @()
                UpnSuffixesCount           = $null
                SpnSuffixes                = @()
                SpnSuffixesCount           = $null
            }
        }
    }

    if($Objects -contains "Computers" -or $Objects -contains "All"){
        $computers = try{
            Write-Verbose "Attempting AD query for Computers"
            Get-ADComputer -Filter * -Properties *
        }catch{
            Write-Error $_
            return $null
        }

        $__MtSession.AdCache.AdComputers = @{
            SetFlag   = $true
            Computers = @($computers)
            Data      = @{
                ComputersCount                 = $(($computers | Measure-Object).Count)
                EnabledComputers               = @()
                EnabledComputersCount          = $null
                DisabledComputers              = @()
                DisabledComputersCount         = $null
                DormantComputers               = @()
                DormantComputersCount          = $null
                ExpiredComputers               = @()
                ExpiredComputersCount          = $null
                StaleComputers                 = @()
                StaleComputersCount            = $null
                StaleComputersRatio            = $null
                NonPgIdCoumputers              = @()
                NonPgIdCoumputersCount         = $null
                SidHistoryComputers            = @()
                SidHistoryComputersCount       = $null
                ContainerComputers             = @()
                ContainerComputersCount        = $null
                BaseDns                        = @()
                BaseDnCount                    = $null
                BaseDnAvg                      = $null
                LowBaseDns                     = @()
                LowBaseDnsCount                = $null
                CreatorSidComputers            = @()
                CreatorSidComputersCount       = $null
                DomainControllers              = @()
                DomainControllersCount         = $null
                ServiceClasses                 = @()
                ServiceClassesCount            = $null
                ServiceClassesComputers        = @()
                ServiceClassesComputersCount   = $null
                UnknownServiceClasses          = @()
                UnknownServiceClassesCount     = $null
                HostBypassComputers            = @()
                HostBypassComputersCount       = $null
                ServiceHosts                   = @()
                ServiceHostsCount              = $null
                ServiceHostsComputers          = @()
                ServiceHostsComputersCount     = $null
                ServiceNoFqdnComputers         = @()
                ServiceNoFqdnComputersCount    = $null
                ServiceDnsBypassComputers      = @()
                ServiceDnsBypassComputersCount = $null
                DnsZones                       = @()
                DnsZonesCount                  = $null
                DnsZoneAvg                     = $null
                LowDnsZones                    = @()
                LowDnsZonesCount               = $null
                NoDnsComputers                 = @()
                NoDnsComputersCount            = $null
                DnsOverlapComputers            = @()
                DnsOverlapComputersCount       = $null
                UnconstrainedComputers         = @()
                UnconstrainedComputersCount    = $null
                KcdComputers                   = @()
                KcdComputersCount              = $null
                S4U2SelfComputers              = @()
                S4U2SelfComputersCount         = $null
                RbcdComputers                  = @()
                RbcdComputersCount             = $null
                MissingSpnsComputers           = @()
                MissingSpnsComputersCount      = $null
                OperatingSystems               = @()
                OperatingSystemsCount          = $null
                NoOperatingSystem              = $()
                NoOperatingSystemCount         = $null
                OperatingSystemAvg             = $null
                LowOperatingSystem             = $()
                LowOperatingSystemCount        = $null
                DisabledComputersRatio         = $null
                DormantComputersRatio          = $null
                ExpiredComputersRatio          = $null
                NonPgIdComputersRatio          = $null
                SidHistoryComputersRatio       = $null
                ContainerComputersRatio        = $null
                CreatorSidComputersRatio       = $null
                ServiceClassesComputersRatio   = $null
                HostBypassComputersRatio       = $null
                ServiceHostsRatio              = $null
                ServiceHostsComputersRatio     = $null
                ServiceDnsBypassComputersRatio = $null
                NoDnsComputersRatio            = $null
                DnsOverlapComputersRatio       = $null
                UnconstrainedComputersRatio    = $null
                KcdComputersRatio              = $null
                S4U2SelfComputersRatio         = $null
                RbcdComputersRatio             = $null
                MissingSpnsComputersRatio      = $null
                NoOperatingSystemRatio         = $null
            }
        }
    }
}