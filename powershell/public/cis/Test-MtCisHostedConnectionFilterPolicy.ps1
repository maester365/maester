<#
.SYNOPSIS
    Checks if connection filter IPs are allow listed

.DESCRIPTION
    The connection filter should not have allow listed IPs
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisHostedConnectionFilterPolicy

    Returns true if the IP allow list is empty

.LINK
    https://maester.dev/docs/commands/Test-MtCisHostedConnectionFilterPolicy
#>
function Test-MtCisHostedConnectionFilterPolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose 'Getting the Hosted Connection Filter policy...'
        $connectionFilterIPAllowList = Get-HostedConnectionFilterPolicy -Identity Default | Select-Object IPAllowList

        Write-Verbose 'Check if the Connection Filter IP allow list is empty'
        $result = $connectionFilterIPAllowList | Where-Object { $_.IPAllowList.Count -ne 0 }

        $testResult = ($result | Measure-Object).Count -eq 0
        if ($testResult) {
            $testResultMarkdown = 'Well done. The connection filter IP allow list was empty ✅'
        } else {
            $testResultMarkdown = 'The connection filter IP allow list was not empty ❌'
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
