<#
.SYNOPSIS
Checks if the Safe Attachments policy is enabled

.DESCRIPTION
The Safe Attachments policy is enabled

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
    }
    elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }
    elseif ($null -eq (Get-MtLicenseInformation -Product Mdo)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    Write-Verbose "Getting Safe Attachment Policy..."
    $policy = Get-MtExo -Request SafeAttachmentPolicy

    $safeAttachmentCheckList = @()

    #Enable
    $safeAttachmentCheckList += [pscustomobject] @{
        "CheckName" = "Enable"
        "Value"     = "True"
    }

    #Action
    $safeAttachmentCheckList += [pscustomobject] @{
        "CheckName" = "Action"
        "Value"     = "Block"
    }

    #QuarantineTag
    $safeAttachmentCheckList += [pscustomobject] @{
        "CheckName" = "QuarantineTag"
        "Value"     = "AdminOnlyAccessPolicy"
    }

    Write-Verbose "Executing checks"
    $failedCheckList = @()
    foreach ($check in $safeAttachmentCheckList) {

        $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }

        if ($checkResult) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += $check.CheckName
        }

    }

    $testResult = ($failedCheckList | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/safeattachmentv2"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the safe attachment policy enabled ($portalLink).`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant does not have the safe attachment policy enabled ($portalLink).`n`n%TestResult%"
    }


    $resultMd = "| Check Name | Result |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $safeAttachmentCheckList) {
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