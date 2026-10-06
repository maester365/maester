function Test-MtCisaContactSharing {
    <#
    .SYNOPSIS
    Checks state of sharing policies

    .DESCRIPTION
    Contact folders SHALL NOT be shared with all domains.

    .EXAMPLE
    Test-MtCisaContactSharing

    Returns true if no sharing policies allow uncontrolled contact sharing.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaContactSharing
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.6.1',
        Title = 'Contact folders SHALL NOT be shared with all domains.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.6.1'),
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = Get-MtExo -Request SharingPolicy

    $resultPolicies = $policies | Where-Object {`
        $_.Enabled -and `
        ($_.Domains -like "`*:*ContactsSharing*" -or `
         $_.Domains -like "Anonymous:*ContactsSharing*")
    }

    $testResult = ($resultPolicies|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant does not allow uncontrolled contact sharing.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant allows uncontrolled contact sharing.`n`n%TestResult%"
    }

    $result = "| Policy Name | Test Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $policies | Sort-Object -Property Name) {
        $portalLink = "https://admin.exchange.microsoft.com/#/individualsharing/:/individualsharingdetails/$($item.ExchangeObjectId)/managedomain"
        $itemResult = "✅ Pass"
        if ($item.ExchangeObjectId -in $resultPolicies.ExchangeObjectId) {
            $itemResult = "❌ Fail"
        }
        $result += "| [$(Get-MtSafeMarkdown $item.Name)]($portalLink) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
