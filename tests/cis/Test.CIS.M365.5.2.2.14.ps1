function Test-MtCisTrustedNamedLocation {
    <#
    .SYNOPSIS
        Checks that at least one trusted IP named location with ranges is defined.

    .DESCRIPTION
        Checks that at least one IP-based named location in Conditional Access has IP ranges and is marked as trusted, so that policies can treat sign-ins from your known networks differently.
        The result also lists the trusted locations whose ranges are all private or otherwise non-routable. They meet the benchmark, but they never match a sign-in: Microsoft Entra ID evaluates the public address that a network uses to reach the internet, never the address of a device on the intranet.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.14, L2)

    .EXAMPLE
        Test-MtCisTrustedNamedLocation

        Returns true if at least one trusted IP named location with ranges exists.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.14
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.14',
        Title = 'Ensure trusted ''named locations'' are defined',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.2.2.14', 'nist-800-53-r5:AC-3'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm',
        Contributor = 'julien-ly'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting named locations...'
    $locations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations'
    $ipLocations = @($locations | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.ipNamedLocation' })

    # Microsoft Entra ID evaluates the public address that a network uses to reach the internet, never the address of
    # a device on the intranet, so a range in private, special-purpose or otherwise non-routable space can't match a sign-in.
    $nonPublicNetworks = @(
        '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',    # Private (RFC 1918)
        '100.64.0.0/10',                                     # Shared address space (RFC 6598)
        '0.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16',        # This network, loopback and link-local
        '192.0.2.0/24', '198.51.100.0/24', '203.0.113.0/24', # Documentation (RFC 5737)
        '198.18.0.0/15',                                     # Benchmarking (RFC 2544)
        '224.0.0.0/4', '240.0.0.0/4',                        # Multicast and reserved
        'fc00::/7', 'fe80::/10', '::1/128', '::/128',        # IPv6 unique local, link-local, loopback and unspecified
        '2001:db8::/32', '3fff::/20',                        # IPv6 documentation (RFC 3849, RFC 9637)
        'ff00::/8'                                           # IPv6 multicast
    )
    $isNonPublicRange = {
        param([string] $Cidr)
        $address, $prefix = $Cidr.Split('/')
        $ip = $null
        if (-not [System.Net.IPAddress]::TryParse($address, [ref]$ip)) { return $false }
        $bytes = $ip.GetAddressBytes()
        $prefixLength = if ($prefix) { [int]$prefix } else { $bytes.Count * 8 }
        foreach ($network in $nonPublicNetworks) {
            $networkAddress, $networkPrefix = $network.Split('/')
            $networkBytes = [System.Net.IPAddress]::Parse($networkAddress).GetAddressBytes()
            # The range lies inside the network when it is at least as narrow and shares the network's prefix bits.
            if ($networkBytes.Count -ne $bytes.Count -or $prefixLength -lt [int]$networkPrefix) { continue }
            $inNetwork = $true
            for ($bit = 0; $bit -lt [int]$networkPrefix; $bit++) {
                $mask = 0x80 -shr ($bit % 8)
                if (($bytes[$bit -shr 3] -band $mask) -ne ($networkBytes[$bit -shr 3] -band $mask)) {
                    $inNetwork = $false
                    break
                }
            }
            if ($inNetwork) { return $true }
        }
        return $false
    }

    $report = foreach ($location in $ipLocations) {
        $ranges = @($location.ipRanges | ForEach-Object { [string]$_.cidrAddress } | Where-Object { $_ })
        $nonPublicRangeCount = @($ranges | Where-Object { & $isNonPublicRange $_ }).Count
        [pscustomobject]@{
            Name            = $location.displayName
            Ranges          = $ranges.Count
            NonPublicRanges = $nonPublicRangeCount
            Trusted         = [bool]$location.isTrusted
            Pass            = $ranges.Count -gt 0 -and $location.isTrusted -eq $true
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    # Trusted locations that meet the benchmark but can't match any sign-in.
    $unmatchable = @($report | Where-Object { $_.Pass -and $_.NonPublicRanges -eq $_.Ranges })

    $passText = 'At least one trusted IP named location with IP ranges is defined.'
    $failText = if ($ipLocations.Count -eq 0) { 'No IP named locations are defined.' } else { 'No IP named location is both trusted and has IP ranges.' }

    $resultMd = "| Named location | IP ranges | Non-public ranges | Trusted | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $(Get-MtSafeMarkdown $row.Name) | $($row.Ranges) | $($row.NonPublicRanges) | $($row.Trusted) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    if ($unmatchable.Count -gt 0) {
        $unmatchableList = ($unmatchable | ForEach-Object { "- $(Get-MtSafeMarkdown $_.Name)" }) -join "`n"
        $testResultMarkdown += "`n`nThe following trusted locations meet the benchmark, but all their ranges are private or otherwise " +
            'non-routable, so they never match a sign-in: Microsoft Entra ID evaluates the public address that a network uses ' +
            "to reach the internet. Add the public ranges of your egress points.`n`n$unmatchableList"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
