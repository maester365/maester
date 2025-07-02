<#
.SYNOPSIS
    Checks if connection filter IPs are allow listed

.DESCRIPTION
    The connection filter should not have the safe list enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisConnectionFilterSafeList

    Returns true if the safe list is not enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisConnectionFilterSafeList
#>
function Test-MtCisConnectionFilterSafeList {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose 'Getting the Hosted Connection Filter policy...'
        $connectionFilterSafeList = Get-HostedConnectionFilterPolicy -Identity Default | Select-Object EnableSafeList

        Write-Verbose 'Check if the Connection Filter safe list is enabled'
        $result = $connectionFilterSafeList | Where-Object { $_.EnableSafeList -eq 'False' }

        $testResult = ($result | Measure-Object).Count -eq 0

        if ($testResult) {
            $testResultMarkdown = 'Well done. The connection filter safe list was not enabled ✅'
        } else {
            $testResultMarkdown = 'The connection filter safe list was enabled ❌'
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
