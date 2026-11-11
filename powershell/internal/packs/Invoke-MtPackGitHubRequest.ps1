function Invoke-MtPackGitHubRequest {
    <#
    .SYNOPSIS
    Calls the GitHub REST API for pack installs (Maester Packs design, section 5.1).

    .DESCRIPTION
    A private repository needs a GitHub token, and a token lifts GitHub's limit of 60 anonymous requests an
    hour. The token is read at the moment of the request (Get-MtPackGitHubToken), is sent to api.github.com
    only, and is kept nowhere. With -OutFile the response is saved to a file (an archive download); GitHub
    redirects those to codeload.github.com, which receives no token.

    With -Token, that token is the only one used. Without it, each source is asked in turn and the first
    that can read the repository is used:

    1. the sign-in Connect-MtGitHub holds for this session, when it is to github.com;
    2. `gh auth token`, when the GitHub CLI is installed and signed in;
    3. the GH_TOKEN environment variable, then GITHUB_TOKEN;
    4. no token.

    A source GitHub answers with 401, 403 or 404 is passed over for the next one, since GitHub answers 404
    for a private repository a token cannot read. Only the name of the source that worked is remembered, for
    each repository, so later requests start with it.

    Returns the parsed JSON, or $null for 404 with -AllowNotFound. Other failures throw with GitHub's
    message and, when the rate limit was reached, how to raise it. -UsedToken says whether a token was sent.
    #>
    [CmdletBinding()]
    [OutputType([object], [object[]], [string])]
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
        [ref] $UsedToken,

        # The -Token of the pack command. When given, no other source is asked.
        [Parameter()]
        [AllowNull()]
        [securestring] $Token
    )

    $uri = "https://api.github.com/$($Path.TrimStart('/'))"
    $labels = @{
        Parameter    = 'the -Token parameter'
        Session      = 'the Connect-MtGitHub sign-in'
        GitHubCli    = 'the GitHub CLI (gh auth token)'
        GH_TOKEN     = 'GH_TOKEN'
        GITHUB_TOKEN = 'GITHUB_TOKEN'
    }
    $explicit = $Token -and $Token.Length -gt 0
    $order = if ($explicit) { @('Parameter') } else { @('Session', 'GitHubCli', 'GH_TOKEN', 'GITHUB_TOKEN', 'Anonymous') }

    # The source that last read this repository goes first. Its name is remembered, never its token.
    if (-not $script:__MtPackGitHubTokenSource) { $script:__MtPackGitHubTokenSource = @{} }
    $repository = if ($Path.TrimStart('/') -match '^repos/([^/?]+/[^/?]+)') { $Matches[1].ToLowerInvariant() }
    $proven = if (-not $explicit -and $repository) { $script:__MtPackGitHubTokenSource[$repository] }
    if ($proven) { $order = @($proven) + @($order | Where-Object { $_ -ne $proven }) }

    $sent = [System.Collections.Generic.List[string]]::new()
    $tried = [System.Collections.Generic.List[string]]::new()
    $failure = $null
    foreach ($source in $order) {
        $value = $null
        if ($source -ne 'Anonymous') {
            $value = Get-MtPackGitHubToken -Source $source -Token $Token
            # gh answers with GH_TOKEN when it is set, so the same token is not sent twice.
            if (-not $value -or $sent.Contains($value)) { continue }
            $sent.Add($value)
            $tried.Add($labels[$source])
        }
        $headers = @{ Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'Maester' }
        if ($value) { $headers['Authorization'] = "Bearer $value" }
        try {
            if ($OutFile) {
                $null = Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $OutFile -MaximumRedirection 5 -ErrorAction Stop
                $result = $OutFile
            } else {
                $result = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
            }
        } catch {
            $status = $null
            if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            $message = $_.ErrorDetails.Message
            try { if ($message) { $message = ($message | ConvertFrom-Json -ErrorAction Stop).message } } catch { Write-Debug $_ }
            if (-not $message) { $message = $_.Exception.Message }
            if ($status -in 403, 429 -and $message -match 'rate limit') {
                $hint = if ($value) { 'Wait for the limit to reset.' } else { 'Sign in with `gh auth login` or Connect-MtGitHub, or pass -Token, to raise the limit.' }
                throw "GitHub's API rate limit was reached while reading $uri. $hint"
            }
            $failure = [pscustomobject]@{ Status = $status; Message = $message }
            # The source that already read this repository says a path is missing: no other source will find it.
            if ($status -eq 404 -and $source -eq $proven) { break }
            if ($status -in 401, 403, 404) {
                if ($source -eq $proven) { $script:__MtPackGitHubTokenSource.Remove($repository) }
                Write-Verbose "GitHub answered $status for $uri with $(if ($value) { $labels[$source] } else { 'no token' })."
                continue
            }
            break
        } finally {
            $headers.Remove('Authorization')
            $value = $null
        }
        if ($UsedToken) { $UsedToken.Value = $source -ne 'Anonymous' }
        if (-not $explicit -and $repository) { $script:__MtPackGitHubTokenSource[$repository] = $source }
        Write-Verbose "Read $uri with $(if ($source -eq 'Anonymous') { 'no token' } else { $labels[$source] })."
        if ($result -is [array]) { return , $result }
        return $result
    }

    if ($UsedToken) { $UsedToken.Value = $tried.Count -gt 0 }
    if ($failure.Status -eq 404) {
        if ($AllowNotFound) { return $null }
        $hint = if ($explicit) {
            ' It does not exist, or the token passed to -Token cannot read it. A fine-grained token needs read-only Contents access to the repository.'
        } elseif ($tried.Count -gt 0) {
            " It does not exist, or it is a private repository that $($tried -join ' and ') cannot read. Pass -Token with a token that can read it."
        } else {
            ' If it is a private repository, sign in with `gh auth login`, or pass -Token with a token that can read it.'
        }
        throw "GitHub returned 404 Not Found for $uri.$hint"
    }
    throw "GitHub request $uri failed$(if ($failure.Status) { " ($($failure.Status))" }): $($failure.Message)"
}
