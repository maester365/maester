<#
.SYNOPSIS
    Checks computer DNS

.DESCRIPTION
    Identifies issues with computer DNS registration

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerDns

    Returns true if AD Computer DNS state is clean

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDns
#>
function Test-MtAdComputerDns {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Proper name')]
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

    if (-not $__MtSession.AdCache.AdComputers.SetFlag){
        Set-MtAdCache -Objects "Computers" -Server $Server -Credential $Credential
    }

    $AdObjects = @{
        Computers = $__MtSession.AdCache.AdComputers.Computers
        Data      = $__MtSession.AdCache.AdComputers.Data
    }

    #region Collect
    $AdObjects.Data.DnsZones = ($AdObjects.Computers | Select-Object @{
        Name       = "DnsZone"
        Expression = {($_.DNSHostName) -replace "^[^.]*\."}
    }).DnsZone | Group-Object | Where-Object {$_.Name -ne ""}
    $AdObjects.Data.DnsZonesCount = ($AdObjects.Data.DnsZones | Measure-Object).Count
    $AdObjects.Data.DnsZoneAvg   = try{
        [Math]::Round($AdObjects.Data.ComputersCount / $AdObjects.Data.DnsZonesCount,2)
    }catch{0}
    $AdObjects.Data.LowDnsZones  = $AdObjects.Data.DnsZones | Where-Object {
        $_.Count -lt $AdObjects.Data.DnsZoneAvg
    }
    $AdObjects.Data.LowDnsZonesCount = ($AdObjects.Data.LowDnsZones | Measure-Object).Count

    $AdObjects.Data.NoDnsComputers = $AdObjects.Computers | Where-Object {
        $null -eq $_.DNSHostName
    }
    $AdObjects.Data.NoDnsComputersCount = ($AdObjects.Data.NoDnsComputers | Measure-Object).Count
    $AdObjects.Data.NoDnsComputersRatio = try{
        $AdObjects.Data.NoDnsComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.DnsOverlapComputers = $AdObjects.Computers | Group-Object DNSHostName | Where-Object {
        $_.Count -gt 1 -and
        $_.Name -ne ""
    }
    $AdObjects.Data.DnsOverlapComputersCount = ($AdObjects.Data.DnsOverlapComputers | Measure-Object).Count
    $AdObjects.Data.DnsOverlapComputersRatio = try{
        $AdObjects.Data.DnsOverlapComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        DnsZones = @{
            Name        = "DNS Zones observed"
            Value       = $AdObjects.Data.DnsZonesCount
            Threshold   = 0.00
            Indicator   = ">"
            Description = "Discrete number of DNS Zones observed in use"
            Status      = $null
        }
        NoDnsComputers = @{
            Name        = "Computers without a DNS Hostname set"
            Value       = $AdObjects.Data.NoDnsComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects without a DNS Hostname set"
            Status      = $null
        }
        DnsOverlapComputers = @{
            Name        = "Computers with overlapping DNS Hostnames"
            Value       = $AdObjects.Data.DnsOverlapComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects where a DNS Hostname is on more than 1 object"
            Status      = $null
        }
        ComputerDnsDensity = @{
            Name        = "Density of Computers in DNS Zones"
            Value       = $AdObjects.Data.DnsZoneAvg
            Threshold   = 1
            Indicator   = ">"
            Description = "Average number of computers per container"
            Status      = $null
        }
        LowDnsZones = @{
            Name        = "DNS Zones with below average number of computers"
            Value       = $AdObjects.Data.LowDnsZonesCount
            Threshold   = 1
            Indicator   = "<="
            Description = "Number of DNS Zones that hold fewer than the average number of computers in Zones"
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
