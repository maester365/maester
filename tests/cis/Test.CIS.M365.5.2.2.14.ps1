function Test-MtCisTrustedNamedLocation {
    <#
    .SYNOPSIS
        Checks that at least one trusted IP named location with a public IP range is defined.

    .DESCRIPTION
        Checks that at least one IP-based named location in Conditional Access has a public IP range and is marked as trusted, so that policies can treat sign-ins from your known networks differently.
        A range in private or other non-routable address space doesn't count: Microsoft Entra ID evaluates the public address that a network uses to reach the internet, never the address of a device on the intranet.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.14, L2)

    .EXAMPLE
        Test-MtCisTrustedNamedLocation

        Returns true if at least one trusted IP named location with a public IP range exists.

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
    # a device on the intranet, so a range in private or other non-routable address space can't match a sign-in.
    $nonPublicNetworks = @(
        '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', # Private (RFC 1918)
        '100.64.0.0/10',                                  # Shared address space (RFC 6598)
        '127.0.0.0/8', '169.254.0.0/16',                  # Loopback and link-local
        'fc00::/7', 'fe80::/10', '::1/128'                # IPv6 unique local, link-local and loopback
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
        $privateRangeCount = @($ranges | Where-Object { & $isNonPublicRange $_ }).Count
        [pscustomobject]@{
            Name          = $location.displayName
            Ranges        = $ranges.Count
            PrivateRanges = $privateRangeCount
            Trusted       = [bool]$location.isTrusted
            Pass          = $ranges.Count -gt $privateRangeCount -and $location.isTrusted -eq $true
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0

    $passText = 'At least one trusted IP named location with a public IP range is defined.'
    $failText = if ($ipLocations.Count -eq 0) {
        'No IP named locations are defined.'
    } elseif (@($report | Where-Object { $_.Trusted -and $_.Ranges -gt 0 -and $_.PrivateRanges -eq $_.Ranges }).Count -gt 0) {
        'No trusted IP named location has a public IP range. Microsoft Entra ID evaluates the public address that a network uses to reach the internet, so private ranges never match a sign-in.'
    } else {
        'No IP named location is both trusted and has IP ranges.'
    }

    $resultMd = "| Named location | IP ranges | Private ranges | Trusted | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $(Get-MtSafeMarkdown $row.Name) | $($row.Ranges) | $($row.PrivateRanges) | $($row.Trusted) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
