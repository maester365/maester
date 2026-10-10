function Test-MtCisHostedConnectionFilterPolicy {
    <#
    .SYNOPSIS
    Checks if connection filter IPs are allow listed

    .DESCRIPTION
    The connection filter should not have allow listed IPs
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.12, L1)

    .EXAMPLE
    Test-MtCisHostedConnectionFilterPolicy

    Returns true if the IP allow list is empty

    .LINK
    https://maester.dev/docs/commands/Test-MtCisHostedConnectionFilterPolicy
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.12',
        Title = 'Ensure the connection filter IP allow list is not used (Only Checks Default Policy)',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Defender',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'knussbaumer'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Hosted Connection Filter policy...'
    $connectionFilterIPAllowList = Get-HostedConnectionFilterPolicy | Where-Object {$_.isDefault -eq $true} | Select-Object IPAllowList

    Write-Verbose 'Check if the Connection Filter IP allow list is empty'
    $testResult = -not $connectionFilterIPAllowList.IPAllowList -or $connectionFilterIPAllowList.IPAllowList.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = 'Well done. The connection filter IP allow list was empty ✅'
    } else {
        $testResultMarkdown = 'The connection filter IP allow list was not empty ❌'
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
