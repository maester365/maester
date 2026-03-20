<#
.SYNOPSIS
    Checks if Anyone link expiration is set to 30 days or less

.DESCRIPTION
    Expiration days for Anyone links SHALL be set to 30 days or less.

    This test is only applicable when the tenant sharing capability is set to Anyone
    (ExternalUserAndGuestSharing). If sharing is more restrictive, Anyone links are not
    available and this control passes automatically.

.EXAMPLE
    Test-MtCisaSpoAnyoneLinkExpiration

    Returns true if Anyone link expiration is 30 days or less, or if Anyone sharing is disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoAnyoneLinkExpiration
#>
function Test-MtCisaSpoAnyoneLinkExpiration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    # This control only applies when sharing is set to Anyone
    if ($spoTenant.SharingCapability -ne 'ExternalUserAndGuestSharing') {
        $testResultMarkdown = "Well done. SharePoint sharing is not set to Anyone, so Anyone link expiration is not applicable. Current sharing level: **$($spoTenant.SharingCapability)**."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $true
    }

    $expirationDays = $spoTenant.RequireAnonymousLinksExpireInDays

    $testResult = $expirationDays -ge 1 -and $expirationDays -le 30

    if ($testResult) {
        $testResultMarkdown = "Well done. Anyone link expiration is set to **$expirationDays** days.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Anyone link expiration is set to **$expirationDays** days. It should be between **1** and **30** days.`n`n%TestResult%"
    }

    $result = "| Setting | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| RequireAnonymousLinksExpireInDays | $expirationDays |`n"
    $result += "| SharingCapability | $($spoTenant.SharingCapability) |`n"

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
