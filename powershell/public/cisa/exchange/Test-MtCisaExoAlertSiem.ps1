<#
.SYNOPSIS
    Checks state of alerts

.DESCRIPTION
    Alerts SHOULD be sent to a monitored address or incorporated into a security information and event management (SIEM) system.

.EXAMPLE
    Test-MtCisaExoAlertSiem

    Returns null

.LINK
    https://maester.dev/docs/commands/Test-MtCisaExoAlertSiem
#>
function Test-MtCisaExoAlertSiem {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif("P1" -notin (Get-MtLicenseInformation -Product MdoV2)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdoP1
        return $null
    } else {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not available for API validation.'
        return $null
    }
}