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
    [MaesterTest(
        Id = 'AD-DCOMP-08',
        Title = 'Computer DNS zone count should be investigated',
        Product = 'ad',
        Feature = 'computers',
        Area = 'infrastructure',
        ResourceType = 'DnsZone',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerDnsZoneCount"
    $adState = Get-MtADDomainState -Categories @('Computers')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers) {
        throw 'Computer inventory is required to review DNS zones.'
    }
    Write-Verbose "Filtering/counting computer dns zone count"

    $computers = $adState.Computers

    # A host name without a suffix is not a DNS zone; report it separately.
    $zoneGroups = @($computers | Where-Object { $_.dNSHostName -match '^[^.]+\..+' } |
            Group-Object -Property { $_.dNSHostName.Substring($_.dNSHostName.IndexOf('.') + 1).TrimEnd('.').ToLowerInvariant() })
    $zoneCount = $zoneGroups.Count
    $computersWithDns = ($computers | Where-Object { $_.dNSHostName } | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Computers | $totalComputers |" + "`n"
    $result += "| Computers with DNS Host Name | $computersWithDns |" + "`n"
    $result += "| Unique DNS Zones | $zoneCount |" + "`n"
    $result += "| Computers without DNS Host Name | $(@($computers | Where-Object { -not $_.dNSHostName }).Count) |`n"
    $result += "| Host Names without DNS Suffix | $(@($computers | Where-Object { $_.dNSHostName -and $_.dNSHostName -notmatch '^[^.]+\..+' }).Count) |`n"

    if ($zoneCount -gt 0) {
        $result += "`n**DNS Zones in Use:**" + "`n" + "`n"
        $result += "| DNS Zone | Computer Count | Percentage of Hosts with Zone |`n| --- | --- | --- |`n"

        foreach ($group in ($zoneGroups | Sort-Object -Property Count -Descending)) {
            $zone = [string]$group.Name -replace '\|', '\|' -replace '[\r\n]', ' '
            $percentage = [Math]::Round(100 * $group.Count / @($computers | Where-Object { $_.dNSHostName -match '^[^.]+\..+' }).Count, 2)
            $result += "| $zone | $($group.Count) | $percentage% |`n"
        }
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "DNS zone distribution has been analyzed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdComputerDnsZoneCount"

    return $testResult
}
