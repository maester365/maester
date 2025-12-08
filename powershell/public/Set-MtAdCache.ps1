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
        [ValidateSet('All', 'Computers')]
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
                HostBypassComputers            = @()
                HostBypassComputersCount       = $null
                ServiceHosts                   = @()
                ServiceHostsCount              = $null
                ServiceHostsComputers          = @()
                ServiceHostsComputersCount     = $null
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