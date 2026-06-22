function Test-MtGsaCompliantNetworkPolicy {
    <#
    .SYNOPSIS
        Checks that an enabled Compliant Network Conditional Access policy is active with the minimum required exclusions.

    .DESCRIPTION
        Verifies that at least one enabled Conditional Access policy enforces the Global Secure Access
        Compliant Network control (block when the session is not on a compliant network - token replay
        protection), and that the policy excludes the Microsoft Intune and Microsoft Intune Enrollment
        apps. Those exclusions are required so devices can enroll before the Global Secure Access client
        exists; without them the policy can block onboarding.

    .EXAMPLE
        Test-MtGsaCompliantNetworkPolicy

        Returns $true if an enabled Compliant Network policy exists and excludes the Intune enrollment apps.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaCompliantNetworkPolicy
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
        # Microsoft Intune and Microsoft Intune Enrollment (well-known first-party app IDs).
        $intuneAppIds = @('0000000a-0000-0000-c000-000000000000', 'd4ebce55-015a-49b5-a083-c84d1797ae8c')

        $compliantNetworkPolicies = Get-MtCompliantNetworkPolicy

        if (-not $compliantNetworkPolicies) {
            $namedLocations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -ApiVersion beta
            $hasCompliantNetworkLocation = @($namedLocations | Where-Object { $_.'@odata.type' -match 'compliantNetworkNamedLocation' }).Count -gt 0
            if (-not $hasCompliantNetworkLocation) {
                Add-MtTestResultDetail -Result 'No Compliant Network named location exists. Enable Global Secure Access Conditional Access signaling first (see Test-MtGsaSignalingEnabled).'
            } else {
                Add-MtTestResultDetail -Result 'No enabled Conditional Access policy enforces the Compliant Network control (block when not on a compliant network).'
            }
            return $false
        }

        $policiesWithExclusions = $compliantNetworkPolicies | Where-Object {
            $excludeApplications = @($_.conditions.applications.excludeApplications)
            @($intuneAppIds | Where-Object { $_ -in $excludeApplications }).Count -eq $intuneAppIds.Count
        }

        $result = [bool]$policiesWithExclusions
        if ($result) {
            $testResult = "Well done. An enabled Conditional Access policy enforces the Compliant Network control and excludes the Microsoft Intune enrollment apps.`n`n"
        } else {
            $testResult = "A Compliant Network enforcement policy exists, but none excludes both **Microsoft Intune** and **Microsoft Intune Enrollment**. Device enrollment can be blocked before the Global Secure Access client is present - add these as application exclusions.`n`n"
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
