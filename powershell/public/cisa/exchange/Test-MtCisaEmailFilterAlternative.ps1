<#
.SYNOPSIS
    Placeholder

.DESCRIPTION
    Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender's Common Attachment Filter.

.EXAMPLE
    Test-MtCisaEmailFilterAlternative

    Allways returns null

.LINK
    https://maester.dev/docs/commands/Test-MtCisaEmailFilterAlternative
#>
function Test-MtCisaEmailFilterAlternative {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ($null -eq (Get-MtLicenseInformation -Product Mdo)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    } else {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Only testing of MDO is supported"
        return $null
    }
}