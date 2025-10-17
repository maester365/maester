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
        $connectionFilterSafeList = Get-HostedConnectionFilterPolicy | Where-Object {$_.isDefault -eq $true} | Select-Object EnableSafeList

        Write-Verbose 'Check if the Connection Filter safe list is enabled'
        $result = $connectionFilterSafeList.EnableSafeList

        # We need to Invert the $result that we don't need to change the Markdown. False in $result is good and True is bad
        $testResult = -not $result

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
