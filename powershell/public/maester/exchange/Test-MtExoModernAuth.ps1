<#
.SYNOPSIS
    Checks if modern authentication for Exchange Online is enabled

.DESCRIPTION
    Modern authentication in Microsoft 365 enables authentication features like multifactor
    authentication (MFA) using smart cards, certificate-based authentication (CBA), and
    third-party SAML identity providers.

.EXAMPLE
    Test-MtExoModernAuth

    Returns true if modern authentication is enabled.

.LINK
    https://maester.dev/docs/commands/Test-MtExoModernAuth
#>
function Test-MtExoModernAuth {
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

        $result = $organizationConfig.OAuth2ClientProfileEnabled

        if ($result) {
            $testResultMarkdown = "Well done. ``OAuth2ClientProfileEnabled`` is ``$($result)```n`n"
        } else {
            $testResultMarkdown = "``OAuth2ClientProfileEnabled`` should be ``True`` and is ``$($result)`` in [SecureScore]($portalLink_SecureScore)`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return $result
}
