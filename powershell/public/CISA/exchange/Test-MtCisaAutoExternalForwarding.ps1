<#
.SYNOPSIS
    Checks ...

.DESCRIPTION

    Automatic forwarding to external domains SHALL be disabled.

.EXAMPLE
    Test-MtCisaAutoExternalForwarding

    Returns true if no domain is enabled for auto forwarding
#>

Function Test-MtCisaAutoExternalForwarding {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $domains = Get-RemoteDomain

    $forwardingDomains = $domains | Where-Object { `
        $_.AutoForwardEnabled
    } | Select-Object -Property DomainName

    $testResult = ($forwardingDomains | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has automatic forwarding disabled."
    } else {
        $testResultMarkdown = "Your tenant does not have automatic forwarding disabled:`n`n%forwardingDomains%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}