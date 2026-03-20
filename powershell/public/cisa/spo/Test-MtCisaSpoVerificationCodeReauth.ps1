<#
.SYNOPSIS
    Checks if verification code reauthentication is set to 30 days or less

.DESCRIPTION
    Reauthentication days for people who use a verification code SHALL be set to 30 days or less.

    This test is only applicable when the tenant sharing capability is set to Anyone
    (ExternalUserAndGuestSharing) or New and existing guests (ExternalUserSharingOnly).
    If sharing is more restrictive, verification codes are not used and this control
    passes automatically.

.EXAMPLE
    Test-MtCisaSpoVerificationCodeReauth

    Returns true if verification code reauthentication is 30 days or less, or if sharing is more restrictive

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoVerificationCodeReauth
#>
function Test-MtCisaSpoVerificationCodeReauth {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    # This control applies when sharing is set to Anyone or New and existing guests
    $applicableSharingLevels = @('ExternalUserAndGuestSharing', 'ExternalUserSharingOnly')
    if ($spoTenant.SharingCapability -notin $applicableSharingLevels) {
        $testResultMarkdown = "Well done. SharePoint sharing is set to **$($spoTenant.SharingCapability)**, so verification code reauthentication is not applicable."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $true
    }

    $reauthDays = $spoTenant.EmailAttestationReAuthDays

    $testResult = $reauthDays -ge 1 -and $reauthDays -le 30

    if ($testResult) {
        $testResultMarkdown = "Well done. Verification code reauthentication is set to **$reauthDays** days.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Verification code reauthentication is set to **$reauthDays** days. It should be between **1** and **30** days.`n`n%TestResult%"
    }

    $result = "| Setting | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| EmailAttestationReAuthDays | $reauthDays |`n"
    $result += "| SharingCapability | $($spoTenant.SharingCapability) |`n"

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
