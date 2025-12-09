<#
.SYNOPSIS
    Checks state of sharing policies

.DESCRIPTION
    Calendar details SHALL NOT be shared with all domains.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisCalendarSharing

    Returns true if no sharing policies allow uncontrolled calendar sharing.

.LINK
    https://maester.dev/docs/commands/Test-MtCisCalendarSharing
#>
function Test-MtCisCalendarSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
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
            $result += "| [$($item.Name)]($portalLink) | $($itemResult) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
