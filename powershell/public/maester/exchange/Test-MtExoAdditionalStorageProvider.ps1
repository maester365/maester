<#
.SYNOPSIS
    Checks if additional storage providers are restricted in Outlook on the web

.DESCRIPTION
    This setting allows users to open certain external files while working in Outlook on the web.
    If allowed, keep in mind that Microsoft doesn't control the use terms or privacy policies of
    those third-party services.

.EXAMPLE
    Test-MtExoAdditionalStorageProvider

    Returns true if additional storage providers are restricted.

.LINK
    https://maester.dev/docs/commands/Test-MtExoAdditionalStorageProvider
#>
function Test-MtExoAdditionalStorageProvider {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose "Getting OWA Mailbox Policy..."
        $owaMailboxPolicy = Get-MtExo -Request OwaMailboxPolicy
        Write-Verbose "Found $($owaMailboxPolicy.Count) Exchange Web mailbox policies"

        $portalLink_SecureScore = "$($__MtSession.AdminPortalUrl.Security)securescore"

        $owaMailboxPolicyDefault = $owaMailboxPolicy | Where-Object { $_.Identity -eq "OwaMailboxPolicy-Default" }
        Write-Verbose "Filtered $($owaMailboxPolicyDefault.Count) Default Web mailbox policy"

        $result = $owaMailboxPolicyDefault.AdditionalStorageProvidersAvailable

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. AdditionalStorageProvidersAvailable is ``$($result)```n`n"
        } else {
            $testResultMarkdown = "``AdditionalStorageProvidersAvailable`` should be ``False`` and is ``$($result)`` in [SecureScore]($portalLink_SecureScore)`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return !$result
}