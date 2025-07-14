<#
.SYNOPSIS
    Checks if Exchange Online Spam Policies are set to notify administrators

.DESCRIPTION
    Ensure Exchange Online Spam Policies are set to notify administrators
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisOutboundSpamFilterPolicy

    Returns true if Exchange Online Spam Policies are set to notify administrators

.LINK
    https://maester.dev/docs/commands/Test-MtCisOutboundSpamFilterPolicy
#>
function Test-MtCisOutboundSpamFilterPolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    try {
        Write-Verbose 'Getting Outbound Spam Filter Policy...'
        $policies = Get-MtExo -Request HostedOutboundSpamFilterPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.Name -eq 'Default' }

        $OutboundSpamFilterPolicyCheckList = @()

        #BccSuspiciousOutboundMail should be True
        $OutboundSpamFilterPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'BccSuspiciousOutboundMail'
            'Value'     = 'True'
        }

        #NotifyOutboundSpam should be True
        $OutboundSpamFilterPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'NotifyOutboundSpam'
            'Value'     = 'True'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $OutboundSpamFilterPolicyCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0

        $portalLink = 'https://security.microsoft.com/antispam'

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenants default Exchange Online Spam policy set to notify administrators ($portalLink).`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenants default Exchange Online Spam policy is not set to notify administrators ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Check Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $OutboundSpamFilterPolicyCheckList) {
            $itemResult = '❌ Fail'
            if ($item.CheckName -notin $failedCheckList) {
                $itemResult = '✅ Pass'
            }
            $resultMd += "| $($item.CheckName) | $($itemResult) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
