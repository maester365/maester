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
        $portalLink_SecureScore = "https://security.microsoft.com/securescore"

        $result = $organizationConfig.OAuth2ClientProfileEnabled

        if ($result -eq $true) {
            $testResultMarkdown = "Well done. ``OAuth2ClientProfileEnabled`` is ``$($result)```n`n"
        } else {
            $testResultMarkdown = "``OAuth2ClientProfileEnabled`` should be ``True`` and is ``$($result)`` in [SecureScore]($portalLink_SecureScore)`n`n"
        }

        $testDetailsMarkdown = "Modern authentication in Microsoft 365 enables authentication features like multifactor authentication (MFA) using smart cards, certificate-based authentication (CBA), and third-party SAML identity providers. When you enable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use modern authentication to log in to Microsoft 365 mailboxes. When you disable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use basic authentication to log in to Microsoft 365 mailboxes. When users initially configure certain email clients, like Outlook 2013 and Outlook 2016, they may be required to authenticate using enhanced authentication mechanisms, such as multifactor authentication. Other Outlook clients that are available in Microsoft 365 (for example, Outlook Mobile and Outlook for Mac 2016) always use modern authentication to log in to Microsoft 365 mailboxes"
        Add-MtTestResultDetail -Description $testDetailsMarkdown -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    }

    return $result
}