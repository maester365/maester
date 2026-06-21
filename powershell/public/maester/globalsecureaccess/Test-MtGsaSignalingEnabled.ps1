function Test-MtGsaSignalingEnabled {
    <#
    .SYNOPSIS
        Checks if Global Secure Access Conditional Access signaling is enabled.

    .DESCRIPTION
        Global Secure Access Conditional Access signaling restores the original client source IP
        to Microsoft Entra ID and Microsoft 365, and enables the Compliant Network signal used for
        token replay protection in Conditional Access. When signaling is disabled, IP-based
        Conditional Access location policies and Identity Protection risk detections lose the user's
        real egress IP, and the Compliant Network signal is unavailable.

        Learn more:
        https://learn.microsoft.com/entra/global-secure-access/how-to-source-ip-restoration

    .EXAMPLE
        Test-MtGsaSignalingEnabled

        Returns $true if Global Secure Access Conditional Access signaling is enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaSignalingEnabled
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
        $settings = Invoke-MtGraphRequest -RelativeUri 'networkAccess/settings/conditionalAccess' -ApiVersion beta -ErrorAction Stop

        $result = [bool]($settings.signalingStatus -eq 'enabled')

        if ($result) {
            $testResult = "Well done. Global Secure Access Conditional Access signaling is **enabled**. Source IP restoration and the Compliant Network signal are available.`n`n"
        } else {
            $testResult = "Global Secure Access Conditional Access signaling is **$($settings.signalingStatus)**.`n`nEnable it in **Global Secure Access > Settings > Session management > Adaptive Access**.`n`n"
        }

        Add-MtTestResultDetail -Result $testResult

        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
