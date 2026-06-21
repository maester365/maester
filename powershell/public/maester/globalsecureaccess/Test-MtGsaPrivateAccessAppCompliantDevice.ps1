function Test-MtGsaPrivateAccessAppCompliantDevice {
    <#
    .SYNOPSIS
        Checks if all Entra Private Access applications are covered by a Conditional Access policy that requires a managed device.

    .DESCRIPTION
        Every Entra Private Access (and Quick Access) application should be protected by an enabled
        Conditional Access policy that requires a managed device - either by targeting the
        application directly or via All cloud apps. A policy satisfies the requirement when it grants
        'compliantDevice' (Intune compliant) or 'domainJoinedDevice' (Microsoft Entra hybrid joined),
        ensuring private apps are only reachable from managed endpoints.

        Note: this check evaluates application coverage only. It does not evaluate whether the policy
        applies to every user of the app (a policy could be scoped to a subset of users).

    .EXAMPLE
        Test-MtGsaPrivateAccessAppCompliantDevice

        Returns $true if every Entra Private Access application is covered by a managed-device policy.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaPrivateAccessAppCompliantDevice
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

        $compliancePolicies = Get-MtConditionalAccessPolicy | Where-Object {
            $_.state -eq 'enabled' -and (
                $_.grantControls.builtInControls -contains 'compliantDevice' -or
                $_.grantControls.builtInControls -contains 'domainJoinedDevice'
            )
        }

        $uncovered = @()
        foreach ($app in $apps) {
            $isCovered = $false
            foreach ($policy in $compliancePolicies) {
                $includeApplications = @($policy.conditions.applications.includeApplications)
                $excludeApplications = @($policy.conditions.applications.excludeApplications)
                if (($includeApplications -contains 'All' -or $includeApplications -contains $app.appId) -and ($excludeApplications -notcontains $app.appId)) {
                    $isCovered = $true
                    break
                }
            }
            if (-not $isCovered) {
                $uncovered += $app
            }
        }

        $result = ($uncovered.Count -eq 0)
        if ($result) {
            $testResult = "Well done. All Entra Private Access applications are covered by a Conditional Access policy that requires a managed device.`n`n"
        } else {
            $testResult = "These Entra Private Access applications are **not** covered by any enabled managed-device Conditional Access policy:`n`n"
            foreach ($app in $uncovered) {
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
