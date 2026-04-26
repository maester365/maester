function Test-MtAdComputerDnsHostNameCount {
    <#
    .SYNOPSIS
    Counts computers with DNS host name configured.

    .DESCRIPTION
    DNS host names (dNSHostName attribute) are essential for proper Kerberos authentication
    and service principal name (SPN) registration. This test counts computers that have
    a DNS host name configured in Active Directory.

    Security Value:
    - DNS host names are required for proper Kerberos authentication
    - Missing DNS host names can cause authentication failures
    - Required for proper SPN registration
    - Important for service discovery and name resolution

    .EXAMPLE
    Test-MtAdComputerDnsHostNameCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDnsHostNameCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers

    # Count computers with and without DNS host name
    $computersWithDns = $computers | Where-Object { $_.dNSHostName -and $_.dNSHostName -ne '' }
    $computersWithoutDns = $computers | Where-Object { -not $_.dNSHostName -or $_.dNSHostName -eq '' }

    $withDnsCount = ($computersWithDns | Measure-Object).Count
    $withoutDnsCount = ($computersWithoutDns | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Computers with DNS Host Name | $withDnsCount |`n"
    $result += "| Computers without DNS Host Name | $withoutDnsCount |`n"

    if ($totalComputers -gt 0) {
        $percentage = [Math]::Round(($withDnsCount / $totalComputers) * 100, 2)
        $result += "| Percentage with DNS Host Name | $percentage% |`n"
    }

    if ($withoutDnsCount -gt 0) {
        $result += "`n**Computers without DNS Host Name (Top 10):**`n`n"
        $result += "| Computer Name | Operating System |`n"
        $result += "| --- | --- |`n"

        foreach ($comp in $computersWithoutDns | Select-Object -First 10) {
            $result += "| $($comp.Name) | $($comp.operatingSystem) |`n"
        }

        if ($withoutDnsCount -gt 10) {
            $result += "| ... and $($withoutDnsCount - 10) more | |`n"
        }
    }

    $testResultMarkdown = "DNS host name configuration has been analyzed. DNS host names are required for proper Kerberos authentication.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


