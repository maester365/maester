function Test-MtGsaConnectorGroupRedundancy {
    <#
    .SYNOPSIS
        Checks that every in-use Microsoft Entra private network connector group has at least two active connectors.

    .DESCRIPTION
        Microsoft Entra private network connectors (shared by Application Proxy and Global Secure Access
        Private Access) should be deployed with redundancy: every connector group that serves traffic
        should contain at least two active connectors on separate hosts, so that a single connector
        outage does not break access to the applications the group serves.

        Connector groups with no connectors are treated as unused (for example the Default onboarding
        pool) and are not evaluated.

    .EXAMPLE
        Test-MtGsaConnectorGroupRedundancy

        Returns $true if every in-use connector group has at least two active connectors.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaConnectorGroupRedundancy
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
        $minimumConnectors = 2

        $connectorGroups = Invoke-MtGraphRequest -RelativeUri 'onPremisesPublishingProfiles/applicationProxy/connectorGroups' -ApiVersion beta |
            Where-Object { $_.connectorGroupType -eq 'applicationProxy' }

        if (-not $connectorGroups) {
            Add-MtTestResultDetail -Result 'No Microsoft Entra private network connector groups were found in this tenant.'
            return $null
        }

        $belowMinimum = @()
        foreach ($group in $connectorGroups) {
            $members = Invoke-MtGraphRequest -RelativeUri "onPremisesPublishingProfiles/applicationProxy/connectorGroups/$($group.id)/members" -ApiVersion beta
            $activeCount = @($members | Where-Object { $_.status -eq 'active' }).Count
            if ($activeCount -ge 1 -and $activeCount -lt $minimumConnectors) {
                $belowMinimum += [pscustomobject]@{
                    Group            = $group.name
                    ActiveConnectors = $activeCount
                }
            }
        }

        $result = ($belowMinimum.Count -eq 0)
        if ($result) {
            $testResult = "Well done. Every in-use private network connector group has at least $minimumConnectors active connectors.`n`n"
        } else {
            $testResult = "These in-use private network connector groups have fewer than $minimumConnectors active connectors (a single connector outage breaks access to the applications they serve):`n`n"
            $testResult += "| Connector group | Active connectors |`n| --- | --- |`n"
            foreach ($entry in $belowMinimum) {
                $testResult += "| $($entry.Group) | $($entry.ActiveConnectors) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
