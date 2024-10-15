<#
.SYNOPSIS
Checks if the anti-phishing policy matches CIS recommendations

.DESCRIPTION
The anti-phishing policy should be enabled, and the settings for PhishThresholdLevel, EnableMailboxIntelligenceProtection, EnableMailboxIntelligence, EnableSpoofIntelligence controls match CIS recommendations

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
    }
    elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }
    elseif ($null -eq (Get-MtLicenseInformation -Product Mdo)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    Write-Verbose "Getting Anti Phishing Policy..."
    $policies = Get-MtExo -Request AntiPhishPolicy

    # We grab the default policy as that is what CIS checks
    $policy = $policies | Where-Object { $_.Name -eq 'Office365 AntiPhish Default' }

    $antiPhishingPolicyCheckList = @()

    # Enabled should be True
    $antiPhishingPolicyCheckList += [pscustomobject] @{
        "CheckName" = "enabled"
        "Value"     = "True"
    }

    # EnableMailboxIntelligenceProtection should be True
    $antiPhishingPolicyCheckList += [pscustomobject] @{
        "CheckName" = "EnableMailboxIntelligenceProtection"
        "Value"     = "True"
    }

    # EnableMailboxIntelligence should be True
    $antiPhishingPolicyCheckList += [pscustomobject] @{
        "CheckName" = "EnableMailboxIntelligence"
        "Value"     = "True"
    }

    # EnableSpoofIntelligence should be True
    $antiPhishingPolicyCheckList += [pscustomobject] @{
        "CheckName" = "EnableSpoofIntelligence"
        "Value"     = "True"
    }

    Write-Verbose "Executing checks"
    $failedCheckList = @()
    foreach ($check in $antiPhishingPolicyCheckList) {

        $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }

        if ($checkResult) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += $check.CheckName
        }

    }

    # Custom check for PhishThresholdLevel
    # Because it is not exact match, we do it seperately
    if ($policy | Where-Object { $_.PhishThresholdLevel -ge 2 }) {
        #If the check fails, add it to the list so we can report on it later
        $failedCheckList += "PhishThresholdLevel"
    }

    $testResult = ($failedCheckList | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/antiphishing"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenants default anti-phishing policy matches CIS recommendations($portalLink).`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenants default anti-phishing policy does not match CIS recommendations ($portalLink).`n`n%TestResult%"
    }


    $resultMd = "| Check Name | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $antiPhishingPolicyCheckList) {
        $itemResult = "❌ Fail"
        if ($item.CheckName -notin $failedCheckList) {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($item.CheckName) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}