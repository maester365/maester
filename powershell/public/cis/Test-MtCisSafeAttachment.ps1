<#
.SYNOPSIS
    Checks if the Safe Attachments policy is enabled

.DESCRIPTION
    The Safe Attachments policy is enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisSafeAttachment

    Returns true safe attachments policy is enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAttachment
#>
function Test-MtCisSafeAttachment {
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
        Write-Verbose 'Getting Safe Attachment Policy...'
        $policies = Get-MtExo -Request SafeAttachmentPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.Name -eq 'Built-In Protection Policy' }

        $safeAttachmentCheckList = @()

        #Enable
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'Enable'
            'Value'     = 'True'
        }

        #Action
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'Action'
            'Value'     = 'Block'
        }

        #QuarantineTag
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'QuarantineTag'
            'Value'     = 'AdminOnlyAccessPolicy'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $safeAttachmentCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0

        $portalLink = 'https://security.microsoft.com/safeattachmentv2'

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenants default safe attachments policy matches CIS recommendations ($portalLink).`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenants default safe attachments policy does not match CIS recommendations ($portalLink).`n`n%TestResult%"
        }

        $resultMd = "| Check Name | Result |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($item in $safeAttachmentCheckList) {
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
