<#
.SYNOPSIS
    Checks state of transport policies

.DESCRIPTION
    External sender warnings SHALL be implemented.

.EXAMPLE
    Test-MtCisaExternalSenderWarning

    Returns true if a transport policy appends a warning.

.LINK
    https://maester.dev/docs/commands/Test-MtCisaExternalSenderWarning
#>
function Test-MtCisaExternalSenderWarning {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $ExternalSenderIdentification = Get-ExternalInOutlook

    if ($ExternalSenderIdentification.Enabled -eq $true) {
        $testResult = $true
    } else {

        $rules = Get-MtExo -Request TransportRule

        $resultRules = $rules | Where-Object {`
                $_.State -eq "Enabled" -and `
                $_.Mode -eq "Enforce" -and `
                $_.FromScope -eq "NotInOrganization" -and `
                $_.SenderAddressLocation -eq "Header" -and `
                $_.PrependSubject -like "*[External]*"
        }

        $testResult = ($resultRules | Measure-Object).Count -ge 1
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has an external sender warning.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an external sender warning.`n`n%TestResult%"
    }

    if ($rules) {
        # Only show table if there are rules
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

    if ( $ExternalSenderIdentification.Enabled -eq $true ) {
        $result = "Exchange External Sender Identification is enabled.`n`n"
        if ( -not [string]::IsNullOrWhiteSpace($ExternalSenderIdentification.AllowList) ) {
            $result += "The following domains are allowed to bypass the external sender warning:`n"
            foreach ( $item in $ExternalSenderIdentification.AllowList ) {
                $result += " * $item`n"
            }
        } else {
            $result += "No domains are allowed to bypass the external sender warning.`n"

        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}