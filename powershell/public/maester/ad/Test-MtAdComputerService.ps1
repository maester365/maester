<#
.SYNOPSIS
    Checks Computer SPNs

.DESCRIPTION
    Identifies potential misconfiguration of computer SPNs

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerService

    Returns true if AD Computer SPNs are proper

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerService
#>
function Test-MtAdComputerService {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential
    )

    if ('ActiveDirectory' -notin $__MtSession.Connections -and 'All' -notin $__MtSession.Connections ) {
        Write-Verbose "ActiveDirectory not set as connection"
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

        # Use on-demand cache helper to fetch only required properties and build indexes
    $cache = Get-MtAdCacheItem -Type Computers -Properties @('DistinguishedName','Name','DNSHostName','LastLogonDate') -Server $Server -Credential $Credential -TtlMinutes 30
    if ($null -eq $cache) { Add-MtTestResultDetail -SkippedBecause CacheFailure; return $null }
    $AdObjects = @{
        Computers = $cache.Data
        Data      = @{}
    }

    #region Collectllect
    $AdObjects.Data.ServiceClasses = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceClasses"
        Expression = {($_.servicePrincipalName) -replace "\/.*$"}
    }).ServiceClasses | Group-Object
    $AdObjects.Data.ServiceClassesCount = ($AdObjects.Data.ServiceClasses | Measure-Object).Count

    $AdObjects.Data.ServiceClassesComputers = $AdObjects.Computers | Select-Object ObjectGUID,@{
        Name       = "ServiceClasses"
        Expression = {
            (($_.servicePrincipalName) -replace "\/.*$") | Sort-Object -Unique
        }
    } | Where-Object {$null -ne $_.ServiceClasses}
    $AdObjects.Data.ServiceClassesComputersCount = ($AdObjects.Data.ServiceClassesComputers | Measure-Object).Count
    $AdObjects.Data.ServiceClassesComputersRatio = try{
        $AdObjects.Data.ServiceClassesComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.UnknownServiceClasses = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceClasses"
        Expression = {($_.servicePrincipalName) -replace "\/.*$"}
    }).ServiceClasses | Group-Object | Where-Object {$_.Name -notin $knownSpns.SPN}
    $AdObjects.Data.UnknownServiceClassesCount = ($AdObjects.Data.UnknownServiceClasses | Measure-Object).Count

    $AdObjects.Data.HostBypassComputers = $AdObjects.Data.ServiceClassesComputers | Select-Object ObjectGUID,@{
        Name       = "ServiceClassesBypassingHost"
        Expression = {
            $_.serviceClasses | ForEach-Object {
                $_ | Where-Object {
                    $_ -in $AdObjects.Data.HostSpnAlias -and
                    $_ -ne "host"
                }
            }
        }
    }
    $AdObjects.Data.HostBypassComputersCount = ($AdObjects.Data.HostBypassComputers | Measure-Object).Count
    $AdObjects.Data.HostBypassComputersRatio = try{
        $AdObjects.Data.UnconstrainedComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceHosts = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceHosts"
        Expression = {($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$"}
    }).ServiceHosts | Group-Object
    $AdObjects.Data.ServiceHostsCount = ($AdObjects.Data.ServiceHosts | Measure-Object).Count
    $AdObjects.Data.ServiceHostsRatio = try{
        $AdObjects.Data.ServiceHostsCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceHostsComputers = $AdObjects.Computers | Select-Object ObjectGUID,@{
        Name       = "ServiceHosts"
        Expression = {
            (($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique
        }
    } | Where-Object {$null -ne $_.ServiceHosts}
    $AdObjects.Data.ServiceHostsComputersCount = ($AdObjects.Data.ServiceHostsComputers | Measure-Object).Count
    $AdObjects.Data.ServiceHostsComputersRatio = try{
        $AdObjects.Data.ServiceHostsComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceNoFqdnComputers = $AdObjects.Computers | Select-Object ObjectGUID,DNSHostName,@{
        Name       = "FqdnCheck"
        Expression = {
            $dnsHostName = $_.DNSHostName
            $null -ne $dnsHostName -and
            $dnsHostName -eq ((($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique | Where-Object {
                $dnsHostName -eq $_
            })
        }
    } | Where-Object {-not $_.FqdnCheck}
    $AdObjects.Data.ServiceNoFqdnComputersCount = ($AdObjects.Data.ServiceNoFqdnComputers | Measure-Object).Count

    $AdObjects.Data.ServiceDnsBypassComputers = $AdObjects.Computers | Select-Object ObjectGUID,DNSHostName,@{
        Name       = "ServiceDnsBypass"
        Expression = {
            $dnsHostName = $_.DNSHostName
            (($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique | ForEach-Object {
                $_ | Where-Object {
                    $_ -ne $dnsHostName -and
                    $_ -ne ($dnsHostName -replace "\..*$")
                }
            }
        }
    } | Where-Object {$null -ne $_.ServiceDnsBypass}
    $AdObjects.Data.ServiceDnsBypassComputersCount = ($AdObjects.Data.ServiceDnsBypassComputers | Measure-Object).Count
    $AdObjects.Data.ServiceDnsBypassComputersRatio = try{
        $AdObjects.Data.ServiceDnsBypassComputersCount / $AdObjects.Data.ServiceHostsComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        ServiceClasses = @{
            Name        = "SPN Service Classes Found"
            Value       = $AdObjects.Data.ServiceClassesCount
            Threshold   = 10
            Indicator   = "<"
            Description = "Discrete number of Service Principal Name (SPN) Service Classes observed"
            Status      = $null
        }
        ServiceClassesComputers = @{
            Name        = "Computers with SPN configured"
            Value       = $AdObjects.Data.ServiceClassesComputersRatio
            Threshold   = 0.3
            Indicator   = "<"
            Description = "Percent of computer objects with Service Principal Names (SPN) configured"
            Status      = $null
        }
        UnknonwServiceClasses = @{
            Name        = "Unknown SPN Service Classes Found"
            Value       = $AdObjects.Data.UnknonwServiceClassesCount
            Threshold   = 0
            Indicator   = "="
            Description = "Discrete number of Service Principal Name (SPN) Service Classes observed where the purpose is not known"
            Status      = $null
        }
        HostBypassComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.HostBypassComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects with Service Principal Names (SPN) configured that overlap with the HOST SPN Service Class alias"
            Status      = $null
        }
        ServiceHosts = @{
            Name        = "Hostnames found in SPNs of computer objects"
            Value       = $AdObjects.Data.ServiceHostsRatio
            Threshold   = 2
            Indicator   = "<"
            Description = "Percent of unique Service Principal Names (SPN) hostnames configured relative to the total number of computer objects"
            Status      = $null
        }
        ServiceHostsComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.ServiceHostsComputersRatio
            Threshold   = 1
            Indicator   = "<"
            Description = "Percent of computer objects with Service Principal Names (SPN) configured relative to the total number of computer objects"
            Status      = $null
        }
        ServiceNoFqdnComputers = @{
            Name        = "Computers without SPN matching DNS Hostname"
            Value       = $AdObjects.Data.ServiceHostsComputersRatio
            Threshold   = 0
            Indicator   = "="
            Description = "Discrete number of computers without Fully Qualified Domain Name (FQDN) Service Principal Names (SPN)"
            Status      = $null
        }
        ServiceDnsBypassComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.ServiceDnsBypassComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects with Service Principal Names (SPN) configured with a service hostname that does not match their DNS hostname"
            Status      = $null
        }
    }
    #endregion

    #region Processing
    foreach($test in $Tests.GetEnumerator()){
        switch($test.Value.Indicator){
            "=" {
                $test.Value.Status = $test.Value.Value -eq $test.Value.Threshold
            }
            "<" {
                $test.Value.Status = $test.Value.Value -lt $test.Value.Threshold
            }
            "<=" {
                $test.Value.Status = $test.Value.Value -le $test.Value.Threshold
            }
            ">" {
                $test.Value.Status = $test.Value.Value -gt $test.Value.Threshold
            }
            ">=" {
                $test.Value.Status = $test.Value.Value -ge $test.Value.Threshold
            }
        }
    }

    $result = $true
    $testResultMarkdown = $null
    foreach($test in $Tests.GetEnumerator()){
        [int]$result *= [int]$test.Value.Status

        $testResultMarkdown += "#### $($test.Value.Name)`n`n"
        $testResultMarkdown += "$($test.Value.Description)`n`n"
        $testResultMarkdown += "| Current State Value | Comparison | Threshold |`n"
        $testResultMarkdown += "| - | - | - |`n"
        $testResultMarkdown += "| $($test.Value.Value) | $($test.Value.Indicator) | $($test.Value.threshold) |`n`n"
        if($test.Value.Status){
            $testResultMarkdown += "Well done. Your current state is in alignment with the threshold.`n`n"
        }else{
            $testResultMarkdown += "Your current state is **NOT** in alignment with the threshold.`n`n"
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return [bool]$result
    #endregion
}
