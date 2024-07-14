﻿<#
.SYNOPSIS
    Checks state of transport policies

.DESCRIPTION

    External sender warnings SHALL be implemented.

.EXAMPLE
    Test-MtCisaExternalSenderWarning

    Returns true if a transport policy appends a warning.
#>

Function Test-MtCisaExternalSenderWarning {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $rules = Get-TransportRule

    $resultRules = $rules | Where-Object {`
            $_.State -eq "Enabled" -and `
            $_.Mode -eq "Enforce" -and `
            $_.FromScope -eq "NotInOrganization" -and `
            $_.SenderAddressLocation -eq "Header" -and `
            $_.PrependSubject -like "*[External]*"
    }

    $testResult = ($resultRules | Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has an external sender warning.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an external sender warning.`n`n%TestResult%"
    }

    if ($rules) { # Only show table if there are rules
        $result = "| Policy Name | Test Result |`n"
        $result += "| --- | --- |`n"
        foreach ($item in $rules | Sort-Object -Property Name) {
            $portalLink = "https://admin.exchange.microsoft.com/#/transportrules/:/ruleDetails/$($item.Guid)/viewinflyoutpanel"
            $itemResult = "❌ Fail"
            if ($resultRules.Guid -contains $item.Guid) {
                $itemResult = "✅ Pass"
            }
            $result += "| [$($item.Name)]($portalLink) | $($itemResult) |`n"
        }
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}