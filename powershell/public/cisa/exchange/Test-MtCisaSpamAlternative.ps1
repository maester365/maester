<#
.SYNOPSIS
    Checks state of spam filter

.DESCRIPTION
    If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft.

.EXAMPLE
    Test-MtCisaSpamAlternative

    Always returns $null

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamAlternative
#>
function Test-MtCisaSpamAlternative {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product Mdo)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }else{
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Unable to validate 3rd party solutions."
        return $null
    }
}