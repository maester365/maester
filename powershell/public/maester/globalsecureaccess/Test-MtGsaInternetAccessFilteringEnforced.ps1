function Test-MtGsaInternetAccessFilteringEnforced {
    <#
    .SYNOPSIS
        Checks that Internet Access traffic is actually filtered when the Internet Access profile is enabled.

    .DESCRIPTION
        When the Global Secure Access Internet Access traffic forwarding profile is enabled, internet
        traffic is acquired and tunnelled through the service. This check verifies that at least one
        filtering enforcement path exists - a Global Secure Access filtering/security profile with an
        enabled policy link (web content filtering, threat intelligence, TLS inspection, or cloud
        firewall). Without one, internet traffic is tunnelled but unprotected (acquired-but-unfiltered
        egress).

    .EXAMPLE
        Test-MtGsaInternetAccessFilteringEnforced

        Returns $true if an enabled filtering profile policy exists while the Internet Access profile is enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaInternetAccessFilteringEnforced
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if ((Get-MtLicenseInformation -Product EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $forwardingProfiles = Invoke-MtGraphRequest -RelativeUri 'networkAccess/forwardingProfiles' -ApiVersion beta
        $internetProfile = $forwardingProfiles | Where-Object { $_.trafficForwardingType -eq 'internet' }
        if (-not ($internetProfile -and $internetProfile.state -eq 'enabled')) {
            Add-MtTestResultDetail -Result 'The Internet Access traffic forwarding profile is not enabled, so no internet traffic is acquired and there is nothing to filter.'
            return $null
        }

        $filteringProfiles = Invoke-MtGraphRequest -RelativeUri 'networkAccess/filteringProfiles' -ApiVersion beta -QueryParameters @{ '$expand' = 'policies' }

        $profilesWithActivePolicy = $filteringProfiles | Where-Object {
            @($_.policies | Where-Object { $_.state -ne 'disabled' }).Count -gt 0
        }

        $result = [bool]$profilesWithActivePolicy
        if ($result) {
            $testResult = "Well done. Internet Access traffic is filtered - at least one Global Secure Access filtering profile has an active policy.`n`n"
        } else {
            $testResult = "The Internet Access profile is enabled but **no filtering is enforced** - no Global Secure Access filtering profile has an active policy. Internet and SaaS traffic is tunnelled but unprotected.`n`n"
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
