function Test-MtGsaPrivateAccessAppSegmentHygiene {
    <#
    .SYNOPSIS
        Checks that no Entra Private Access application segment uses a broad or risky destination.

    .DESCRIPTION
        Reviews the application segments of Entra Private Access (and Quick Access) applications and
        flags destinations that break least-privilege or carry operational risk:

        - destinationType 'dnsSuffix' - a broad namespace catch-all that commonly masks a missing or
          incorrect Private DNS suffix.
        - Wildcard FQDN (destinationHost contains '*').
        - Single-label FQDN (destinationType 'fqdn' with no dot, e.g. 'fileserver') - relies on the
          synthetic Global Secure Access suffix and carries a Kerberos SPN risk.
        - All-IP destinations (0.0.0.0/0 or ::/0).

    .EXAMPLE
        Test-MtGsaPrivateAccessAppSegmentHygiene

        Returns $true if no application segment uses a broad or risky destination.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaPrivateAccessAppSegmentHygiene
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
        $segments = Invoke-MtGraphRequest -RelativeUri 'onPremisesPublishingProfiles/applicationProxy/applicationSegments' -ApiVersion beta -QueryParameters @{ '$expand' = 'application' }
        if (-not $segments) {
            Add-MtTestResultDetail -Result 'No Entra Private Access application segments were found in this tenant.'
            return $null
        }

        $riskySegments = @()
        foreach ($segment in $segments) {
            $destinationHost = [string]$segment.destinationHost
            $destinationType = [string]$segment.destinationType
            $reason = $null

            if ($destinationType -eq 'dnsSuffix') {
                $reason = 'dnsSuffix (broad namespace catch-all; can mask a missing Private DNS suffix)'
            } elseif ($destinationHost.Contains('*')) {
                $reason = 'wildcard FQDN'
            } elseif ($destinationType -eq 'fqdn' -and -not $destinationHost.Contains('.')) {
                $reason = 'single-label FQDN (synthetic-suffix / Kerberos SPN risk)'
            } elseif ($destinationHost -in @('0.0.0.0/0', '::/0')) {
                $reason = 'all-IP destination'
            }

            if ($reason) {
                $riskySegments += [pscustomobject]@{
                    Application = $segment.application.displayName
                    Destination = $destinationHost
                    Type        = $destinationType
                    Reason      = $reason
                }
            }
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
