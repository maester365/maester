function Test-MtAdComputerDnsZoneCount {
    <#
    .SYNOPSIS
    Counts unique DNS zones used by domain computers.

    .DESCRIPTION
    This test identifies the number of unique DNS zones that domain computers
    are registered in. Multiple DNS zones may indicate disjoint namespaces,
    multi-domain environments, or DNS configuration issues.

    Security Value:
    - Identifies DNS zone distribution across the domain
    - Helps detect disjoint namespace configurations
    - Supports DNS security assessment
    - Important for Kerberos and service discovery

    .EXAMPLE
    Test-MtAdComputerDnsZoneCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDnsZoneCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerDnsZoneCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting computer dns zone count"

    $computers = $adState.Computers

    # Extract DNS zones from dNSHostName
    $dnsZones = @()
    foreach ($computer in $computers) {
        if ($computer.dNSHostName) {
            $dnsName = $computer.dNSHostName.ToString()
            # Extract zone (everything after first dot)
            if ($dnsName -match '\.') {
                $zone = $dnsName.Substring($dnsName.IndexOf('.') + 1)
                if ($zone -and $dnsZones -notcontains $zone) {
                    $dnsZones += $zone
                }
            }
        }
    }

    $zoneCount = $dnsZones.Count
    $computersWithDns = ($computers | Where-Object { $_.dNSHostName } | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Computers with DNS Host Name | $computersWithDns |`n"
    $result += "| Unique DNS Zones | $zoneCount |`n"

    if ($zoneCount -gt 0) {
        $result += "`n**DNS Zones in Use:**`n`n"
        $result += "| DNS Zone |`n"
        $result += "| --- |`n"

        foreach ($zone in ($dnsZones | Sort-Object)) {
            $result += "| $zone |`n"
        }
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "DNS zone distribution has been analyzed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdComputerDnsZoneCount"

    return $testResult
}


