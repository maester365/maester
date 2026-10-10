function Test-MtCisCalendarSharing {
    <#
    .SYNOPSIS
    Checks state of sharing policies

    .DESCRIPTION
    Calendar details SHALL NOT be shared with all domains.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.3, L2)

    .EXAMPLE
    Test-MtCisCalendarSharing

    Returns true if no sharing policies allow uncontrolled calendar sharing.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCalendarSharing
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.3',
        Title = 'Ensure ''External sharing'' of calendars is not available',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Microsoft 365',
        Tag = ('CIS E3', 'CIS E3 Level 2', 'CIS M365 v7.0.0', 'L2'),
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = ('merill', 'NZLostboy')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Get Calendar sharing policy'
    $policies = Get-MtExo -Request SharingPolicy

    Write-Verbose 'Get Calendars where sharing policy is enabled and allows anonymous sharing'
    $resultPolicies = $policies | Where-Object {
        $_.Enabled -and ($_.Domains -like "`*:*CalendarSharing*" -or $_.Domains -like 'Anonymous:*CalendarSharing*')
    }

    $testResult = ($resultPolicies | Measure-Object).Count -eq 0
    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not allow uncontrolled calendar sharing.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant allows uncontrolled calendar sharing.`n`n%TestResult%"
    }

    $result = "| Policy Name | Test Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $policies | Sort-Object -Property Name) {
        $portalLink = "https://admin.exchange.microsoft.com/#/individualsharing/:/individualsharingdetails/$($item.ExchangeObjectId)/managedomain"
        $itemResult = '✅ Pass'
        if ($item.ExchangeObjectId -in $resultPolicies.ExchangeObjectId) {
            $itemResult = '❌ Fail'
        }
        $result += "| [$(Get-MtSafeMarkdown $item.Name)]($portalLink) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
