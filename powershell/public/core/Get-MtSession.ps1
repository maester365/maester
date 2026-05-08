function Get-MtSession {
    <#
    .SYNOPSIS
    Gets the current Maester session information which includes the current Graph base uri and other details.
    These are read-only and should not be modified directly.

    .DESCRIPTION
    The session information can be used to troubleshoot issues with the Maester module.

    For security, the GitHubAuthHeader Authorization value is redacted on output so a copied
    session dump cannot leak the GitHub PAT. The live session used by internal callers is unchanged.

    .EXAMPLE
    Get-MtSession

    Returns the current Maester session information.

    .LINK
    https://maester.dev/docs/commands/Get-MtSession
    #>
    [CmdletBinding()]
    param()

    Write-Verbose 'Getting the current Maester session information.'

    $sessionCopy = @{}
    foreach ($key in $__MtSession.Keys) {
        $sessionCopy[$key] = $__MtSession[$key]
    }

    $authHeader = $__MtSession['GitHubAuthHeader']
    if ($null -ne $authHeader) {
        if ($authHeader -is [System.Collections.IDictionary]) {
            $redactedHeader = [ordered]@{}
            foreach ($k in $authHeader.Keys) {
                if ($k -ieq 'Authorization') {
                    $redactedHeader[$k] = '<redacted>'
                } else {
                    $redactedHeader[$k] = $authHeader[$k]
                }
            }
            $sessionCopy['GitHubAuthHeader'] = $redactedHeader
        } else {
            $sessionCopy['GitHubAuthHeader'] = '<redacted>'
        }
    }

    Write-Output $sessionCopy
}
