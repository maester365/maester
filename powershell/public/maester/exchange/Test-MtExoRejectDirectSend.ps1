<#
.SYNOPSIS
    Checks if direct send is configured to reject

.DESCRIPTION
    Attackers can exploit direct send to send spam or phishing emails without authentication.
    Direct Send covers anonymous messages (unauthenticated messages) sent from your own domain
    to your organization's mailboxes using the tenant MX

.EXAMPLE
    Test-MtExoRejectDirectSend

    Returns true if direct send is configured to reject

.LINK
    https://maester.dev/docs/commands/Test-MtExoRejectDirectSend
#>
function Test-MtExoRejectDirectSend {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose "Getting Organization..."
        $organizationConfig = Get-MtExo -Request OrganizationConfig

        $result = $organizationConfig.RejectDirectSend

        if ($result) {
            $testResultMarkdown = "Well done. RejectDirectSend is ``$($result)``.`n`n"
        } else {
            $testResultMarkdown = "``RejectDirectSend`` should be ``True``. RejectDirectSend is ``$($result)``.`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return $result
}