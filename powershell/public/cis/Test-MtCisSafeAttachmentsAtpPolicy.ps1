<#
.SYNOPSIS
    Checks if Safe Attachments for SharePoint, OneDrive, and Microsoft Teams are enabled

.DESCRIPTION
    Safe Attachments for SharePoint, OneDrive, and Microsoft Teams should be enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisSafeAttachmentsAtpPolicy

    Enabled for SharePoint, OneDrive, and Microsoft Teams

.LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAttachmentsAtpPolicy
#>
function Test-MtCisSafeAttachmentsAtpPolicy {
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
        Write-Verbose 'Getting 365 Atp Policy...'
        $policy = Get-MtExo -Request AtpPolicyForO365

        $atpPolicyCheckList = @()

        #EnableATPForSPOTeamsODB should be True
        $atpPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableATPForSPOTeamsODB'
            'Value'     = 'True'
        }

        #EnableSafeDocs should be True
        $atpPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeDocs'
            'Value'     = 'True'
        }

        #AllowSafeDocsOpen should be False
        $atpPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'AllowSafeDocsOpen'
            'Value'     = 'False'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()
        foreach ($check in $atpPolicyCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0

        $portalLink = 'https://security.microsoft.com/safeattachmentv2'

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant has Safe Attachments for SharePoint, OneDrive, and Microsoft Teams enabled ($portalLink).`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant does not have Safe Attachments for SharePoint, OneDrive, and Microsoft Teams enabled ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Check Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $atpPolicyCheckList) {
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
