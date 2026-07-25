function Test-MtGsaPrivateAccessAppSegmentHygiene {
    <#
    .SYNOPSIS
        Checks that no Entra Private Access application segment uses a broad or risky destination.

    .DESCRIPTION
        Reviews the application segments of Entra Private Access (and Quick Access) applications and
        flags destinations that break least-privilege or carry operational risk:

        - destinationType 'dnsSuffix' that is a bare top-level domain (single label, e.g. 'com' / 'net' /
          'local') - a TLD-wide catch-all. A normal scoped suffix (e.g. 'contoso.com') is the recommended
          resolution path and is not flagged.
        - Wildcard FQDN (destinationHost contains '*').
        - Single-label FQDN (destinationType 'fqdn' with no dot, e.g. 'fileserver') - relies on the
          synthetic Global Secure Access suffix and carries a Kerberos SPN risk.
        - servicePrincipalName segments (Kerberos SPNs such as 'HTTP/*') are a legitimate construct and
          are not evaluated.
        - Broad IP ranges (near-default routes) - the portal's broadest selectable mask is /1, so an
          exact 0.0.0.0/0 rarely appears; segments broader than /16 are flagged instead, so a /16 -
          common for 10.x networks - still passes. (Global Secure Access is IPv4-only, so IPv6 segments
          are not evaluated.) Finer least-privilege CIDR sweeps (e.g. < /24) are intentionally left to
          the overlapping ZTA segment check this will be merged with.

    .EXAMPLE
        Test-MtGsaPrivateAccessAppSegmentHygiene

        Returns $true if no application segment uses a broad or risky destination.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaPrivateAccessAppSegmentHygiene
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # A CIDR segment whose prefix length is *below* this value (broader than /16) is flagged as a broad / near-default route. A /16 - common for 10.x networks - and narrower pass. (GSA is IPv4-only, so IPv6 segments are not evaluated.)
        [int] $BroadIPv4MaskThreshold = 16
    )

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if ((Get-MtLicenseInformation -Product EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $apps = Get-MtPrivateAccessApplication
        if (-not $apps) {
            Add-MtTestResultDetail -Result 'No Entra Private Access applications were found in this tenant.'
            return $null
        }

        # Read each application's segments from its own onPremisesPublishing configuration (the documented
        # per-app endpoint). Graph failures propagate to the outer catch (indeterminate / skip).
        $riskySegments = @()
        $segmentCount = 0
        foreach ($app in $apps) {
            $appObject = Invoke-MtGraphRequest -RelativeUri 'applications' -Filter "appId eq '$($app.appId)'" -ApiVersion beta | Select-Object -First 1
            if (-not $appObject) { continue }

            $segments = Invoke-MtGraphRequest -RelativeUri "applications/$($appObject.id)/onPremisesPublishing/segmentsConfiguration/microsoft.graph.ipSegmentConfiguration/applicationSegments" -ApiVersion beta -ErrorAction Stop
            foreach ($segment in $segments) {
                $segmentCount++
                $destinationHost = [string]$segment.destinationHost
                $destinationType = [string]$segment.destinationType
                $reason = $null

                # Kerberos SPN segments (e.g. 'HTTP/*') are a legitimate Private Access construct - not evaluated.
                if ($destinationType -eq 'servicePrincipalName') { continue }

                if ($destinationType -eq 'dnsSuffix') {
                    # A Private DNS suffix is the recommended resolution path; only a bare top-level domain
                    # (single label, e.g. 'com' / 'net' / 'local') is a dangerously broad catch-all. A
                    # normal scoped suffix such as 'contoso.com' is not flagged.
                    if (-not $destinationHost.Contains('.')) {
                        $reason = 'top-level-domain dnsSuffix (catches an entire TLD namespace)'
                    }
                } elseif ($destinationHost.Contains('*')) {
                    $reason = 'wildcard FQDN'
                } elseif ($destinationType -eq 'fqdn' -and -not $destinationHost.Contains('.')) {
                    $reason = 'single-label FQDN (synthetic-suffix / Kerberos SPN risk)'
                } elseif ($destinationHost -match '/(\d+)\s*$' -and -not $destinationHost.Contains(':')) {
                    # GSA is IPv4-only; IPv6 segments are not evaluated.
                    $prefix = [int]$Matches[1]
                    if ($prefix -lt $BroadIPv4MaskThreshold) {
                        $reason = if ($prefix -eq 0) { 'all-IP destination (default route)' } else { "broad IP range (/$prefix - near-default route)" }
                    }
                }

                if ($reason) {
                    $riskySegments += [pscustomobject]@{
                        Application = $app.displayName
                        Destination = $destinationHost
                        Type        = $destinationType
                        Reason      = $reason
                    }
                }
            }
        }

        if ($segmentCount -eq 0) {
            Add-MtTestResultDetail -Result 'No Entra Private Access application segments were found in this tenant.'
            return $null
        }

        $result = ($riskySegments.Count -eq 0)
        if ($result) {
            $testResult = "Well done. No Entra Private Access application segment uses a broad or risky destination.`n`n"
        } else {
            $testResult = "These Entra Private Access application segments use broad or risky destinations (least-privilege and Kerberos concerns):`n`n"
            $testResult += "| Application | Destination | Type | Issue |`n| --- | --- | --- | --- |`n"
            foreach ($entry in $riskySegments) {
                $testResult += "| $($entry.Application) | $($entry.Destination) | $($entry.Type) | $($entry.Reason) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
