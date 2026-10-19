function Invoke-MtPackGitHubRequest {
    <#
    .SYNOPSIS
    Calls the GitHub REST API for pack installs (Maester Packs design, section 5.1).

    .DESCRIPTION
    Sends GH_TOKEN or GITHUB_TOKEN, when one is set, to api.github.com only: a private repository needs it,
    and it lifts GitHub's limit of 60 anonymous requests an hour. With -OutFile the response is saved to a
    file (an archive download); GitHub redirects those to codeload.github.com, which receives no token.

    Returns the parsed JSON, or $null for 404 with -AllowNotFound. Other failures throw with GitHub's
    message and, when the rate limit was reached, how to raise it. -UsedToken says whether a token was sent.
    #>
    [CmdletBinding()]
    [OutputType([object], [string])]
    param(
        # The path after https://api.github.com/, such as 'repos/contoso/pack'.
        [Parameter(Mandatory)]
        [string] $Path,

        # Save the body to this file instead of parsing it.
        [Parameter()]
        [string] $OutFile,

        # Return $null for 404 instead of throwing.
        [Parameter()]
        [switch] $AllowNotFound,

        # Receives whether a token was sent (a [ref] to a bool).
        [Parameter()]
        [ref] $UsedToken
    )

    $token = if ($env:GH_TOKEN) { $env:GH_TOKEN } elseif ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { $null }
    if ($UsedToken) { $UsedToken.Value = [bool]$token }
    $headers = @{ Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'Maester' }
    if ($token) { $headers['Authorization'] = "Bearer $token" }
    $uri = "https://api.github.com/$($Path.TrimStart('/'))"
    try {
        if ($OutFile) {
            $null = Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $OutFile -MaximumRedirection 5 -ErrorAction Stop
            return $OutFile
        }
        Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
    } catch {
        $status = $null
        if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 404 -and $AllowNotFound) { return $null }
        $message = $_.ErrorDetails.Message
        try { if ($message) { $message = ($message | ConvertFrom-Json -ErrorAction Stop).message } } catch { Write-Debug $_ }
        if (-not $message) { $message = $_.Exception.Message }
        if ($status -in 403, 429 -and $message -match 'rate limit') {
            $hint = if ($token) { 'Wait for the limit to reset.' } else { 'Set GH_TOKEN (for example from `gh auth token`) to raise the limit.' }
            throw "GitHub's API rate limit was reached while reading $uri. $hint"
        }
        if ($status -eq 404) {
            $hint = if ($token) { '' } else { ' If it is a private repository, set GH_TOKEN to a token that can read it.' }
            throw "GitHub returned 404 Not Found for $uri.$hint"
        }
        throw "GitHub request $uri failed$(if ($status) { " ($status)" }): $message"
    }
}
