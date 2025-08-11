<#
.SYNOPSIS
    Checks if MailTips are enabled for end users

.DESCRIPTION
    MailTips assist end users with identifying strange patterns to emails they send.
    This helps protect against accidental information disclosure and phishing attempts.

.EXAMPLE
    Test-MtExoMailTip

    Returns true if MailTips are enabled for end users.

.LINK
    https://maester.dev/docs/commands/Test-MtExoMailTip
#>
function Test-MtExoMailTip {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose "Getting Organization Config..."
        $organizationConfig = Get-MtExo -Request OrganizationConfig
        $portalLink_SecureScore = "$($__MtSession.AdminPortalUrl.Security)securescore"

        $result = $organizationConfig.MailTipsExternalRecipientsTipsEnabled

        if ($result) {
            $testResultMarkdown = "Well done. ``MailTipsExternalRecipientsTipsEnabled`` is ``$($result)```n`n"
        } else {
            $testResultMarkdown = "``MailTipsExternalRecipientsTipsEnabled`` should be ``True`` and is ``$($result)`` in [SecureScore]($portalLink_SecureScore)`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return $result
}