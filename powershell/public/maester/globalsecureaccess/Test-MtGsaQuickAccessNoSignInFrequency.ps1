function Test-MtGsaQuickAccessNoSignInFrequency {
    <#
    .SYNOPSIS
        Checks that no Conditional Access sign-in frequency control applies to the Global Secure Access Quick Access app.

    .DESCRIPTION
        When Private DNS is hosted on the Quick Access application, the Global Secure Access client's DNS
        queries authenticate against the Quick Access app and are evaluated by Conditional Access. A
        sign-in frequency session control then re-triggers on those frequent DNS lookups, causing
        unexpected and repeated authentication prompts. Microsoft therefore recommends not applying a
        sign-in frequency control to Quick Access.

        This is an operational / user-experience hygiene check, not a security gap. Remediation is to
        exclude the Quick Access app from the sign-in frequency policy - not to remove the control
        organization-wide.

    .EXAMPLE
        Test-MtGsaQuickAccessNoSignInFrequency

        Returns $true if no enabled sign-in frequency policy covers the Quick Access app.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaQuickAccessNoSignInFrequency
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
        $quickAccess = Get-MtPrivateAccessApplication | Where-Object { $_.tags -contains 'NetworkAccessQuickAccessApplication' } | Select-Object -First 1
        if (-not $quickAccess) {
            Add-MtTestResultDetail -Result 'No Quick Access application was found (Global Secure Access Private Access is not configured).'
            return $null
        }
        $quickAccessAppId = $quickAccess.appId

        $offendingPolicies = Get-MtConditionalAccessPolicy | Where-Object {
            $_.state -eq 'enabled' -and
            $_.sessionControls.signInFrequency.isEnabled -eq $true -and
            (
                (@($_.conditions.applications.includeApplications) -contains $quickAccessAppId) -or
                (
                    (@($_.conditions.applications.includeApplications) -contains 'All') -and
                    (@($_.conditions.applications.excludeApplications) -notcontains $quickAccessAppId)
                )
            )
        }

        $result = (@($offendingPolicies).Count -eq 0)
        if ($result) {
            $testResult = "Well done. No sign-in frequency Conditional Access control applies to the Quick Access app.`n`n"
        } else {
            $testResult = "These enabled Conditional Access policies apply a **sign-in frequency** control to the Quick Access app. Private DNS lookups can re-trigger authentication prompts - **exclude the Quick Access app** from each policy (keep the control for everything else):`n`n"
            foreach ($policy in $offendingPolicies) {
                $testResult += "* $($policy.displayName)`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
