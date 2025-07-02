<#
.SYNOPSIS
    Checks if the anti-phishing policy matches CIS recommendations

.DESCRIPTION
    The anti-phishing policy should be enabled, and the settings for PhishThresholdLevel, EnableMailboxIntelligenceProtection, EnableMailboxIntelligence, EnableSpoofIntelligence controls match CIS recommendations
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisSafeAntiPhishingPolicy

    Returns true if the default anti-phishing policy matches CIS recommendations

.LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAntiPhishingPolicy
#>
function Test-MtCisSafeAntiPhishingPolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ('P1' -notin (Get-MtLicenseInformation -Product MdoV2)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdoP1
        return $null
    }

    try {
        Write-Verbose 'Getting Anti Phishing Policy...'
        $policies = Get-MtExo -Request AntiPhishPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.Name -eq 'Office365 AntiPhish Default' }

        $antiPhishingPolicyCheckList = @()

        # Enabled should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'Enabled'
            'Value'     = 'True'
        }

        # EnableMailboxIntelligenceProtection should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableMailboxIntelligenceProtection'
            'Value'     = 'True'
        }

        # EnableMailboxIntelligence should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableMailboxIntelligence'
            'Value'     = 'True'
        }

        # EnableSpoofIntelligence should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSpoofIntelligence'
            'Value'     = 'True'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $antiPhishingPolicyCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        # Custom check for PhishThresholdLevel
        # Because it is not exact match, the above logic won't work. Manual check to see if PhishThresholdLevel is 2 or greater
        if ($policy | Where-Object { $_.PhishThresholdLevel -le 1 }) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += 'PhishThresholdLevel'
        }

        # We didn't use this in the foreach loop above, but we need to add it now so we get results in the output for the separate check
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'PhishThresholdLevel'
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0

        $portalLink = 'https://security.microsoft.com/antiphishing'

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenants default anti-phishing policy matches CIS recommendations($portalLink).`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenants default anti-phishing policy does not match CIS recommendations ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Check Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $antiPhishingPolicyCheckList) {
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
