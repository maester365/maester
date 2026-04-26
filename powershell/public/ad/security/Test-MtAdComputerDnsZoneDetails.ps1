function Test-MtAdComputerDnsZoneDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of computers by DNS zone.

    .DESCRIPTION
    This test provides a comprehensive view of how computers are distributed
    across DNS zones in the domain. This helps identify disjoint namespaces,
    multi-domain scenarios, and potential DNS configuration issues.

    Security Value:
    - Identifies computers in unexpected DNS zones
    - Supports disjoint namespace assessment
    - Helps detect DNS misconfigurations
    - Important for Kerberos realm configuration

    .EXAMPLE
    Test-MtAdComputerDnsZoneDetails

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDnsZoneDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers

    # Group computers by DNS zone
    $zoneGroups = $computers | Where-Object { $_.dNSHostName } | ForEach-Object {
        $dnsName = $_.dNSHostName.ToString()
        if ($dnsName -match '\.') {
            $zone = $dnsName.Substring($dnsName.IndexOf('.') + 1)
            [PSCustomObject]@{
                Computer = $_
                Zone     = $zone
            }
        } else {
            [PSCustomObject]@{
                Computer = $_
                Zone     = "(No Zone)"
            }
        }
    } | Group-Object -Property Zone

    $computersWithDns = ($computers | Where-Object { $_.dNSHostName } | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count
    $zoneCount = ($zoneGroups | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Computers with DNS Host Name | $computersWithDns |`n"
    $result += "| Unique DNS Zones | $zoneCount |`n"

    if ($zoneCount -gt 0) {
        $result += "`n**Computers by DNS Zone:**`n`n"
        $result += "| DNS Zone | Computer Count | Percentage |`n"
        $result += "| --- | --- | --- |`n"

        $sortedGroups = $zoneGroups | Sort-Object -Property Count -Descending
        foreach ($group in $sortedGroups) {
            $percentage = if ($computersWithDns -gt 0) { [Math]::Round(($group.Count / $computersWithDns) * 100, 2) } else { 0 }
            $result += "| $($group.Name) | $($group.Count) | $percentage% |`n"
        }
    }

    # List computers without DNS host name
    $computersWithoutDns = $computers | Where-Object { -not $_.dNSHostName }
    $withoutDnsCount = ($computersWithoutDns | Measure-Object).Count

    if ($withoutDnsCount -gt 0) {
        $result += "`n**Computers without DNS Host Name:** $withoutDnsCount**`n`n"
        $result += "| Computer Name | Operating System |`n"
        $result += "| --- | --- |`n"

        foreach ($comp in $computersWithoutDns | Select-Object -First 10) {
            $result += "| $($comp.Name) | $($comp.operatingSystem) |`n"
        }

        if ($withoutDnsCount -gt 10) {
            $result += "| ... and $($withoutDnsCount - 10) more | |`n"
        }
    }

    $testResultMarkdown = "Detailed DNS zone distribution has been analyzed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


