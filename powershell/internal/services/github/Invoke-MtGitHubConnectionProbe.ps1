function Invoke-MtGitHubConnectionProbe {
    <#
    .SYNOPSIS
    Internal: Sends a GitHub connection probe with shared rate-limit tracking.
    .DESCRIPTION
    Checks the connection's cooldown before sending a GET request, then records rate-limit
    state from the response or error. Returns the unparsed response and lets the caller
    decide whether a probe failure blocks the connection. Both request timeouts are 30 seconds.
    .PARAMETER Uri
    The absolute GitHub API URI to probe.
    .PARAMETER Headers
    The authentication and API headers prepared by Connect-MtGitHub.
    .PARAMETER Connection
    The shared connection object used for rate-limit tracking throughout the probes.
    .EXAMPLE
    Invoke-MtGitHubConnectionProbe -Uri "$ApiBaseUri/user" -Headers $AuthHeaders -Connection $RateLimitConnection

    Probes token identity using the supplied headers and connection's rate-limit state.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [Parameter(Mandatory)] [hashtable] $Headers,
        [Parameter(Mandatory)] [object] $Connection
    )
    Invoke-MtGitHubRateLimitGuard -Api REST -Connection $Connection
    try {
        $Response = Invoke-WebRequest -Uri $Uri -Headers $Headers -Method GET -UseBasicParsing -ConnectionTimeoutSeconds 30 -OperationTimeoutSeconds 30 -ErrorAction Stop
        Invoke-MtGitHubRateLimitGuard -Api REST -Connection $Connection -Headers $Response.Headers
        return $Response
    } catch {
        Invoke-MtGitHubRateLimitGuard -Api REST -Connection $Connection -ErrorRecord $_
        throw
    }
}
