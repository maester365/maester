function Test-MtCisConnectionFilterSafeList {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have the safe list enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.13, L1)

    .EXAMPLE
    Test-MtCisConnectionFilterSafeList

    Returns true if the safe list is not enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisConnectionFilterSafeList
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.13',
        Title = 'Ensure the connection filter safe list is off (Only Checks Default Policy)',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'knussbaumer'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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
}
