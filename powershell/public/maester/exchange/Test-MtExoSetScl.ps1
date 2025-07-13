<#
.SYNOPSIS
    Checks if Spam confidence level (SCL) is configured in mail transport rules with specific domains

.DESCRIPTION
    This command checks if Spam confidence level (SCL) is properly configured in mail transport rules.
    Allow-listing domains in transport rules bypasses regular malware and phishing scanning, which can
    enable an attacker to launch attacks against your users from a safe haven domain.

.EXAMPLE
    Test-MtExoSetScl

    Returns true if SetScl is not in use in transport rules.

.LINK
    https://maester.dev/docs/commands/Test-MtExoSetScl
#>
function Test-MtExoSetScl {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        $portalLink_TransportRules = "https://admin.exchange.microsoft.com/#/transportrules"

        Write-Verbose "Getting Transport Rules..."
        $exchangeTransportRule = Get-MtExo -Request TransportRule
        Write-Verbose "Found $($exchangeTransportRule.Count) Exchange Transport rules"

        $ruleWithSCL = $exchangeTransportRule | Where-Object { $_.SetScl -match "-1" }
        $result = ($ruleWithSCL).Count -gt 0

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. SetScl is not in use`n`n"
        } else {
            $testResultMarkdown = "SetScl is used $(($ruleWithSCL).Count) times in [Rules]($portalLink_TransportRules)`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null

        return $null
    }

    return !$result
}