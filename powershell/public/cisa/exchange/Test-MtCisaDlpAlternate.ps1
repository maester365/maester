<#
.SYNOPSIS
    This will always return $null

.DESCRIPTION
    The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft.

.EXAMPLE
    Test-MtCisaDlpAlternate

    Always will return $null

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDlpAlternate
#>
function Test-MtCisaDlpAlternate {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #Add License Check
    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }else{
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Unable to validate 3rd party solutions."
        return $null
    }
}