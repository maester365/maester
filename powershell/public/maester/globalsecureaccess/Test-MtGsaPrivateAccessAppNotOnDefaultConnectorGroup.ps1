function Test-MtGsaPrivateAccessAppNotOnDefaultConnectorGroup {
    <#
    .SYNOPSIS
        Checks that no Entra Private Access application is served by the Default connector group.

    .DESCRIPTION
        Newly installed Microsoft Entra private network connectors automatically join the Default
        connector group. If an application is served by the Default group, a freshly installed or
        misconfigured connector immediately begins handling its traffic - a routing and outage risk.
        The Default group should stay an idle / onboarding pool, and every Private Access application
        should be served through a dedicated connector group.

    .EXAMPLE
        Test-MtGsaPrivateAccessAppNotOnDefaultConnectorGroup

        Returns $true if no Entra Private Access application is assigned to the Default connector group.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaPrivateAccessAppNotOnDefaultConnectorGroup
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
        $apps = Get-MtPrivateAccessApplication
        if (-not $apps) {
            Add-MtTestResultDetail -Result 'No Entra Private Access applications were found in this tenant.'
            return $null
        }

        $onDefault = @()
        foreach ($app in $apps) {
            $appObject = Invoke-MtGraphRequest -RelativeUri 'applications' -Filter "appId eq '$($app.appId)'" -ApiVersion beta | Select-Object -First 1
            if (-not $appObject) {
                continue
            }

            $connectorGroup = $null
            try {
                $connectorGroup = Invoke-MtGraphRequest -RelativeUri "applications/$($appObject.id)/connectorGroup" -ApiVersion beta -ErrorAction Stop
            } catch {
                # An app without a resolvable connector group is not treated as a finding here.
                $connectorGroup = $null
            }

            if ($connectorGroup -and $connectorGroup.isDefault -eq $true) {
                $onDefault += $app
            }
        }

        $result = ($onDefault.Count -eq 0)
        if ($result) {
            $testResult = "Well done. No Entra Private Access application is assigned to the **Default** connector group.`n`n"
        } else {
            $testResult = "These Entra Private Access applications are served by the **Default** connector group. New connectors auto-join Default, so move them to a dedicated connector group:`n`n"
            foreach ($app in $onDefault) {
                $testResult += "* $($app.displayName)`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
