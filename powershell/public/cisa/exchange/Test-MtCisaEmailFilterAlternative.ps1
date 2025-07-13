<#
.SYNOPSIS
    Placeholder

.DESCRIPTION
    Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender's Common Attachment Filter.

.EXAMPLE
    Test-MtCisaEmailFilterAlternative

    Always returns null

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
    } elseif ( 'Eop' -in (Get-MtLicenseInformation -Product Eop) -or 'Eop' -in (Get-MtLicenseInformation -Product MdoV2) ) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Tenant is licensed for Exchange Online Protection; an alternative mail filter is not needed."
        return $null
    } else {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Tenant is not licensed for Exchange Online Protection and there is no implementation to check for alternate mail filters available."
        return $null
    }
}
