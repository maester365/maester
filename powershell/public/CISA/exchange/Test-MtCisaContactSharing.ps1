<#
.SYNOPSIS
    Checks state of sharing policies

.DESCRIPTION

    Contact folders SHALL NOT be shared with all domains.

.EXAMPLE
    Test-MtCisaSmtpAuthentication

    Returns true if no sharing policies allow uncontrolled contact sharing.
#>

Function Test-MtCisaContactSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = Get-SharingPolicy

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
        $result += "| [$($item.Name)]($portalLink) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}