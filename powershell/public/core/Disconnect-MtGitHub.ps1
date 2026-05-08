function Disconnect-MtGitHub {
    <#
    .SYNOPSIS
    Clears the current GitHub REST session in Maester.

    .DESCRIPTION
    Removes the GitHub PAT-derived auth header, the connection metadata, and the per-session
    REST response cache from the Maester module's session state. Idempotent — safe to call when
    no GitHub session is active.

    Use this when you want to drop the in-memory token, switch organizations, or clean up
    troubleshooting state. Disconnect-Maester also calls this automatically (Disconnect-MtGraph
    alias does not, to preserve its narrow Graph-only semantic).

    .EXAMPLE
    Disconnect-MtGitHub

    Clears any active GitHub session.

    .LINK
    https://maester.dev/docs/commands/Disconnect-MtGitHub
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Consistent with other Connect/Disconnect-* functions')]
    [CmdletBinding()]
    param()

    $hadState = ($null -ne $__MtSession.GitHubConnection) -or ($null -ne $__MtSession.GitHubAuthHeader)

    $__MtSession.GitHubConnection = $null
    $__MtSession.GitHubAuthHeader = $null
    $__MtSession.GitHubCache = @{}

    if ($hadState) {
        Write-Host 'Disconnected from GitHub.' -ForegroundColor Green
    } else {
        Write-Verbose 'No GitHub session to disconnect.'
    }
}
