function Test-MtGsaM365ProfileEnabled {
    <#
    .SYNOPSIS
        Checks if the Microsoft 365 traffic forwarding profile in Global Secure Access is enabled.

    .DESCRIPTION
        The Microsoft 365 traffic forwarding profile routes Microsoft 365 traffic (Exchange Online,
        SharePoint Online, Teams) through Global Secure Access. Enabling it is the lowest-risk entry
        point to Global Secure Access and unlocks source IP restoration, the Compliant Network signal
        in Conditional Access (token replay protection), Universal Tenant Restrictions, and network
        access traffic logging.

        Learn more:
        https://learn.microsoft.com/entra/global-secure-access/concept-traffic-forwarding

    .EXAMPLE
        Test-MtGsaM365ProfileEnabled

        Returns $true if the Microsoft 365 traffic forwarding profile exists and is enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaM365ProfileEnabled
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
        $forwardingProfiles = Invoke-MtGraphRequest -RelativeUri 'networkAccess/forwardingProfiles' -ApiVersion beta -ErrorAction Stop
        $m365Profile = $forwardingProfiles | Where-Object { $_.trafficForwardingType -eq 'm365' }

        $result = [bool]($m365Profile -and $m365Profile.state -eq 'enabled')

        if ($result) {
            $testResult = "Well done. The Microsoft 365 traffic forwarding profile is **enabled**.`n`n"
        } elseif ($m365Profile) {
            $testResult = "The Microsoft 365 traffic forwarding profile exists but is **$($m365Profile.state)**.`n`nEnable it in **Global Secure Access > Connect > Traffic forwarding**.`n`n"
        } else {
            $testResult = "No Microsoft 365 traffic forwarding profile was found. Global Secure Access might not be onboarded in this tenant.`n`n"
        }

        Add-MtTestResultDetail -Result $testResult

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
