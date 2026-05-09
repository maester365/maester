function Connect-MtGitHub {
    <#
    .SYNOPSIS
    Establishes a GitHub Enterprise Cloud organization REST API session for Maester.

    .DESCRIPTION
    Establishes a GitHub Enterprise Cloud organization REST API session for Maester CIS
    benchmark tests. This is an organization-scoped session, not a full enterprise-admin
    session: enterprise-admin endpoints under /enterprises/{enterprise} are not verified
    by this command and would require a future enterprise-access probe if CIS controls
    need them.

    If no explicit token is provided, Maester signs in with the Maester CLI GitHub App
    using GitHub device flow. If the app is not installed or approved for the requested
    organization, Maester asks before opening the app install page and retries the org
    access probes after the user completes the GitHub install/approval step. If the
    user declines, Maester prints token-based auth guidance instead. It then validates
    the resulting token via four probes. The first three are blocking (any failure
    aborts the connection); the fourth is
    non-blocking (failure emits a warning but the session is still established):
      1. GET /user                            — token identity (blocking)
      2. GET /orgs/{org}                      — org metadata (blocking)
      3. GET /user/memberships/orgs/{org}     — signed-in user's org membership (blocking)
      4. GET /orgs/{org}/actions/permissions  — administration access probe (non-blocking)

    The membership probe is the real access gate: /orgs/{org} returns public metadata
    even for tokens with no relationship to the organization. Probe 3 intentionally
    uses /user/memberships/orgs/{org} because it verifies the signed-in user's own
    membership without requiring permission to read another user's membership record.
    A 4xx, malformed body, or missing state/role aborts with FailureReason =
    'OrgMembershipFailed'. A successful response whose membership state is anything
    other than 'active' (e.g. 'pending' for an invitation that has not been accepted)
    also aborts the connection, with FailureReason = 'OrgMembershipPending' — only an
    active membership proves the user can act on the organization.

    Probe 4 verifies the token can reach an org-administration endpoint. GitHub
    documents /orgs/{org}/actions/permissions as requiring classic PAT 'admin:org' or
    fine-grained 'Organization Administration: read'. Failure here records
    AdministrationPermissionVerified = $false and emits a warning, but does not flip
    Connected to $false — the session remains usable for controls that don't require
    org administration access.

    On success, Role = 'admin' + RoleState = 'active' + AdministrationPermissionVerified
    = $true is the no-warning path. Other active roles (member, billing_manager, etc.)
    or admin-probe failure still connect but emit warnings indicating limited CIS
    coverage. Non-active membership states do not connect at all.

    Token resolution order:
      1. -Token parameter (SecureString)
      2. MAESTER_GITHUB_TOKEN environment variable
      3. GH_TOKEN environment variable (GitHub CLI convention)
      4. Maester CLI GitHub App device flow (interactive sessions)

    Required permissions:
      Maester GitHub App: Organization Members: read + Organization Administration: read
      Classic PAT:        admin:org
      Fine-grained PAT:   Organization Members: read + Organization Administration: read
      Required role for full coverage: organization owner/admin

    Note: Connection success proves token validity and org access, not that all
    CIS control fields will be visible. Each CIS test validates field availability
    and skips with an informative message if required fields are absent.

    .PARAMETER Organization
    GitHub organization login name. Falls back to GitHubOrganization in maester-config.json.

    .PARAMETER Token
    GitHub token as SecureString. Falls back to MAESTER_GITHUB_TOKEN, GH_TOKEN, or the
    Maester CLI GitHub App device flow.

    .PARAMETER ApiBaseUri
    GitHub API base URI. Falls back to GitHubApiBaseUri config, then https://api.github.com.
    Set to https://api.{subdomain}.ghe.com for GHE.com EMU deployments.

    .PARAMETER ApiVersion
    GitHub REST API version date. Falls back to GitHubApiVersion config, then 2022-11-28.
    GitHub defaults requests without X-GitHub-Api-Version to 2022-11-28.

    .EXAMPLE
    Connect-MtGitHub -Organization 'mycompany'

    .EXAMPLE
    Connect-MtGitHub -Organization 'mycompany' -ApiBaseUri 'https://api.myco.ghe.com'

    .LINK
    https://maester.dev/docs/commands/Connect-MtGitHub
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Consistent with other Connect-* functions')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Organization,

        [Parameter(Mandatory = $false)]
        [securestring] $Token,

        [Parameter(Mandatory = $false)]
        [string] $ApiBaseUri,

        [Parameter(Mandatory = $false)]
        [string] $ApiVersion
    )

    # Clear prior GitHub session state (prevents stale data on reconnect)
    $__MtSession.GitHubConnection = $null
    $__MtSession.GitHubAuthHeader = $null
    $__MtSession.GitHubCache = @{}

    # Lazy-load config once if MaesterConfig is not yet set and any config-backed parameter is
    # omitted. This makes the config fallback work when Connect-MtGitHub is called before
    # Invoke-Maester (the normal pre-run workflow). Get-MtMaesterConfig walks up to 5 parent
    # directories from the given path, so it finds the config from anywhere in the test tree.
    if ($null -eq $__MtSession.MaesterConfig -and (
            [string]::IsNullOrWhiteSpace($Organization) -or
            [string]::IsNullOrWhiteSpace($ApiBaseUri) -or
            [string]::IsNullOrWhiteSpace($ApiVersion))) {
        $__MtSession.MaesterConfig = Get-MtMaesterConfig -Path (Get-Location).Path
    }

    # Resolve organization (param -> config -> error)
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        $Organization = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubOrganization'
    }
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        Write-Host "`nNo GitHub organization specified. Provide -Organization or set GitHubOrganization in maester-config.json." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NotConfigured' }
        return
    }
    # Surrounding whitespace from a config file or shell-quoted parameter would otherwise
    # be URL-encoded into the probe paths and silently 404 against GitHub.
    $Organization = $Organization.Trim()

    # Resolve ApiBaseUri (param -> config -> default).
    $resolvedApiBaseUri = $ApiBaseUri
    if ([string]::IsNullOrWhiteSpace($resolvedApiBaseUri)) {
        $configApiBaseUri = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiBaseUri'
        if (-not [string]::IsNullOrWhiteSpace($configApiBaseUri)) { $resolvedApiBaseUri = $configApiBaseUri }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedApiBaseUri)) { $resolvedApiBaseUri = 'https://api.github.com' }
    $resolvedApiBaseUri = $resolvedApiBaseUri.Trim().TrimEnd('/')

    # Validate the fully-resolved URI. Done in-body (not via parameter [ValidatePattern]) so
    # config-supplied values are checked too, and so an invalid value records InvalidApiBaseUri
    # after the session-clearing logic at the top of this function rather than throwing before it.
    # Host allowlist prevents the GitHub token from being sent to arbitrary HTTPS hosts: only the
    # documented GitHub API endpoints — api.github.com (SaaS) and api.<subdomain>.ghe.com
    # (GHE.com data residency) — are accepted. GHES on-prem is intentionally not supported.
    $parsedUri = $null
    if (-not [uri]::TryCreate($resolvedApiBaseUri, [UriKind]::Absolute, [ref]$parsedUri) -or $parsedUri.Scheme -cne 'https') {
        Write-Host "`nGitHub API base URI must be an absolute https:// URI. Got: '$resolvedApiBaseUri'." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'InvalidApiBaseUri' }
        return
    }
    $uriHost = $parsedUri.Host.ToLowerInvariant()
    $isGitHubSaas = $uriHost -eq 'api.github.com'
    $isGheCom     = $uriHost -match '^api\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.ghe\.com$'
    $hasRootPath  = [string]::IsNullOrEmpty($parsedUri.AbsolutePath) -or $parsedUri.AbsolutePath -eq '/'
    # Reject query strings, fragments, and non-default ports — none are valid for the
    # GitHub API base, and accepting them would let an attacker-supplied config redirect
    # the GitHub token to an unexpected listener (e.g. a debug proxy on :8443) while still passing
    # the host allowlist.
    $hasNoQuery    = [string]::IsNullOrEmpty($parsedUri.Query)
    $hasNoFragment = [string]::IsNullOrEmpty($parsedUri.Fragment)
    $hasDefaultPort = $parsedUri.IsDefaultPort
    if (-not (($isGitHubSaas -or $isGheCom) -and $hasRootPath -and $hasNoQuery -and $hasNoFragment -and $hasDefaultPort)) {
        Write-Host "`nGitHub API base URI must be https://api.github.com or https://api.<subdomain>.ghe.com (no path, query, fragment, or non-default port). Got: '$resolvedApiBaseUri'." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'InvalidApiBaseUri' }
        return
    }
    $ApiBaseUri = $resolvedApiBaseUri

    # Resolve ApiVersion (param -> config -> default). Validation runs on the resolved value
    # so the same FailureReason path applies whether the bad value came from -ApiVersion or
    # GitHubApiVersion config — a parameter [ValidatePattern] would otherwise throw before
    # the session-clearing logic at the top of this function ran.
    $resolvedApiVersion = $ApiVersion
    if ([string]::IsNullOrWhiteSpace($resolvedApiVersion)) {
        $configApiVersion = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiVersion'
        if (-not [string]::IsNullOrWhiteSpace($configApiVersion)) { $resolvedApiVersion = $configApiVersion }
    }
    # 2022-11-28 is GitHub's initial REST API version and the documented default for
    # unversioned requests. Re-test before changing this pin: GitHub documents that
    # API versions are supported for at least 24 months after a successor is released.
    # Latest version at PR 2 implementation time: 2026-03-10.
    # See: https://docs.github.com/en/rest/about-the-rest-api/api-versions
    if ([string]::IsNullOrWhiteSpace($resolvedApiVersion)) { $resolvedApiVersion = '2022-11-28' }
    $resolvedApiVersion = $resolvedApiVersion.Trim()

    if ($resolvedApiVersion -notmatch '^\d{4}-\d{2}-\d{2}$') {
        Write-Host "`nGitHub API version must use YYYY-MM-DD format. Got: '$resolvedApiVersion'." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'InvalidApiVersion' }
        return
    }
    $ApiVersion = $resolvedApiVersion

    # Resolve token (param -> MAESTER_GITHUB_TOKEN -> GH_TOKEN -> Maester GitHub App device flow)
    $maesterGitHubAppClientId = 'Iv23liV3mw0hSq0gn957'
    $maesterGitHubAppInstallUrl = 'https://github.com/apps/maester-cli/installations/new'
    $plainToken = $null
    $authenticationType = $null
    $tokenExpiresAt = $null
    $bstr = [IntPtr]::Zero
    try {
        if ($Token) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
            $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $authenticationType = 'TokenParameter'
        } elseif (-not [string]::IsNullOrEmpty($env:MAESTER_GITHUB_TOKEN)) {
            $plainToken = $env:MAESTER_GITHUB_TOKEN
            $authenticationType = 'MAESTER_GITHUB_TOKEN'
        } elseif (-not [string]::IsNullOrEmpty($env:GH_TOKEN)) {
            $plainToken = $env:GH_TOKEN
            $authenticationType = 'GH_TOKEN'
        }
    } finally {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }

    if ([string]::IsNullOrEmpty($plainToken) -and (Get-MtUserInteractive)) {
        $deviceToken = Get-MtGitHubAppDeviceToken -ClientId $maesterGitHubAppClientId
        if ($null -eq $deviceToken -or [string]::IsNullOrWhiteSpace([string]$deviceToken.AccessToken)) {
            $failureReason = if ($null -ne $deviceToken -and -not [string]::IsNullOrWhiteSpace([string]$deviceToken.FailureReason)) { [string]$deviceToken.FailureReason } else { 'GitHubDeviceFlowFailed' }
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = $failureReason }
            return
        }
        $plainToken = [string]$deviceToken.AccessToken
        $authenticationType = 'GitHubAppDeviceFlow'
        if ($deviceToken.PSObject.Properties.Name -contains 'ExpiresAt') {
            $tokenExpiresAt = $deviceToken.ExpiresAt
        }
    }

    if ([string]::IsNullOrEmpty($plainToken)) {
        Write-Host "`nNo GitHub token found. Run Connect-MtGitHub in an interactive session to sign in with the Maester GitHub App, or provide -Token / MAESTER_GITHUB_TOKEN / GH_TOKEN for automation." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NoToken' }
        return
    }

    # Auth headers — token stored here, NOT in the connection object
    $authHeaders = @{
        Authorization          = "Bearer $plainToken"
        Accept                 = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = $ApiVersion
        'User-Agent'           = 'Maester-GitHubCis'
    }
    Remove-Variable -Name plainToken -ErrorAction SilentlyContinue

    # Probe 1: token identity
    try {
        $userResponse = Invoke-WebRequest -Uri "$ApiBaseUri/user" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop
        $user = $userResponse.Content | ConvertFrom-Json
        Write-Verbose "GitHub token identity: $($user.login)"
    } catch {
        $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
        if ($rateLimitMessage) {
            Write-Host "`n$rateLimitMessage" -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'RateLimited' }
            return
        }
        $code   = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        $apiMsg = Get-MtGitHubErrorMessage    -ErrorRecord $_
        # 410 = unsupported API version. 400 with a message about API/version support
        # also indicates an unsupported X-GitHub-Api-Version header value — GitHub's
        # documented wording includes "Not a supported version" and "version is not supported".
        $isUnsupportedApiVersion = $code -eq 410 -or ($code -eq 400 -and $apiMsg -match '(?i)api\s+version|x-github-api-version|not\s+.*supported.*version|version.*not\s+.*supported')
        if ($isUnsupportedApiVersion) {
            Write-Host "`nGitHub API version '$ApiVersion' is not supported by GitHub. Update GitHubApiVersion or omit it to use the default." -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'InvalidApiVersion' }
            return
        }
        # $null status code means no HTTP response was produced (DNS failure, TLS handshake
        # failure, connection refused, hostname unreachable). The GitHub token was never evaluated and
        # the URI itself didn't resolve to a working endpoint — commonly a wrong GHE base URI.
        if ($null -eq $code) {
            Write-Host "`nGitHub API base URI '$ApiBaseUri' is not reachable (no response). Verify network connectivity, DNS/TLS, and the GitHubApiBaseUri value (use https://api.{subdomain}.ghe.com for GHE.com)." -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiBaseUriFailed' }
            return
        }
        # 5xx means GitHub responded but the endpoint is failing — the URI is fine, the
        # service is unavailable. Don't conflate with token or base-URI problems.
        if ($code -ge 500 -and $code -le 599) {
            Write-Host "`nGitHub API request failed (HTTP $code). The GitHub service may be temporarily unavailable; check https://www.githubstatus.com/ and retry." -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiUnavailable' }
            return
        }
        if ($code -eq 401) {
            Write-Host "`nGitHub token validation failed (HTTP 401). Verify the GitHub authorization is valid and not expired." -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
            return
        }
        Write-Host "`nGitHub token validation failed (HTTP $code). Verify the GitHub authorization is valid and not expired." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
        return
    }

    # Probe 2: org access
    $encodedOrg = [System.Uri]::EscapeDataString($Organization)
    $orgInstallPrompted = $false
    $orgData = $null
    $planName = $null
    $role         = $null
    $roleState    = $null
    $roleWarning  = $null

    while ($true) {
        $orgData = $null
        $planName = $null
        $role = $null
        $roleState = $null
        $roleWarning = $null

        try {
            $orgResponse = Invoke-WebRequest -Uri "$ApiBaseUri/orgs/$encodedOrg" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop
            $orgData = $orgResponse.Content | ConvertFrom-Json
        } catch {
            $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
            if ($rateLimitMessage) {
                Write-Host "`n$rateLimitMessage" -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'RateLimited' }
                return
            }
            $code = Get-MtGitHubErrorStatusCode -ErrorRecord $_
            $apiMsg = Get-MtGitHubErrorMessage -ErrorRecord $_
            # Same transport/5xx classification as /user — a probe that gets to the network can
            # still fail for reasons unrelated to org access (DNS hiccup, partial outage), and
            # those should report ApiBaseUriFailed / ApiUnavailable rather than OrgAccessFailed.
            if ($null -eq $code) {
                Write-Host "`nGitHub API base URI '$ApiBaseUri' is not reachable (no response) while probing /orgs/$Organization. Verify network connectivity, DNS/TLS, and the GitHubApiBaseUri value." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiBaseUriFailed' }
                return
            }
            if ($code -ge 500 -and $code -le 599) {
                Write-Host "`nGitHub API request failed (HTTP $code) while probing /orgs/$Organization. The GitHub service may be temporarily unavailable; check https://www.githubstatus.com/ and retry." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiUnavailable' }
                return
            }
            if ($authenticationType -eq 'GitHubAppDeviceFlow' -and -not $orgInstallPrompted -and $code -eq 403) {
                $orgInstallPrompted = Request-MtGitHubAppOrganizationInstall -Organization $Organization -InstallUrl $maesterGitHubAppInstallUrl -Reason $apiMsg
                if ($orgInstallPrompted) {
                    continue
                }
            }
            $msg = switch ($code) {
                403     { "Access denied (403). For Maester GitHub App auth, install/approve the app for '$Organization' ($maesterGitHubAppInstallUrl) and authorize as an organization member or owner. For token auth, verify the token has the required organization permissions. GitHub API: $apiMsg" }
                404     { "Organization '$Organization' not found (404). Check the organization login name. GitHub API: $apiMsg" }
                default { "HTTP $code. $apiMsg" }
            }
            Write-Host "`nFailed to access GitHub organization: $msg" -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgAccessFailed' }
            return
        }

        # Null-safe plan name (not visible for all token types/roles)
        if ($orgData.PSObject.Properties.Name -contains 'plan' -and $null -ne $orgData.plan) {
            $planName = $orgData.plan.name
        }

        # Probe 3: signed-in user's org membership / role — blocking proof of org access.
        # /orgs/{org} returns public org metadata even for tokens with no relationship to the org.
        # Use /user/memberships/orgs/{org} so the token only has to prove its own membership,
        # not read an arbitrary /orgs/{org}/memberships/{username} record.
        try {
            $membershipResponse = Invoke-WebRequest -Uri "$ApiBaseUri/user/memberships/orgs/$encodedOrg" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop

            $membershipData = $null
            try {
                $membershipData = $membershipResponse.Content | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $membershipData = $null
            }

            $hasState = $null -ne $membershipData -and $membershipData.PSObject.Properties.Name -contains 'state' -and -not [string]::IsNullOrWhiteSpace([string]$membershipData.state)
            $hasRole  = $null -ne $membershipData -and $membershipData.PSObject.Properties.Name -contains 'role'  -and -not [string]::IsNullOrWhiteSpace([string]$membershipData.role)

            if (-not ($hasState -and $hasRole)) {
                Write-Host "`nGitHub organization membership could not be verified: malformed response from /user/memberships/orgs/$Organization." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipFailed' }
                return
            }

            $role      = [string]$membershipData.role
            $roleState = [string]$membershipData.state

            # Only an 'active' membership proves the user can actually act on the org.
            # 'pending' (invitation not accepted) and any other non-active state should
            # not be treated as a usable session — org-scoped controls would silently
            # fail or report misleading data. Fail closed and do not retain auth state.
            if ($roleState -ne 'active') {
                Write-Host "`nGitHub organization membership is not active (state: '$roleState'). Accept the organization invitation in GitHub and reconnect." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipPending' }
                return
            }

            if ($role -ne 'admin') {
                $roleWarning = "GitHub organization admin/owner permissions required for full CIS coverage. Current role: '$role'. Some controls may skip or report limited visibility."
            }
        } catch {
            $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
            if ($rateLimitMessage) {
                Write-Host "`n$rateLimitMessage" -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'RateLimited' }
                return
            }
            $code   = Get-MtGitHubErrorStatusCode -ErrorRecord $_
            $apiMsg = Get-MtGitHubErrorMessage    -ErrorRecord $_
            # Same transport/5xx classification as /user — separating "the network/service broke"
            # from "the token cannot prove membership" matters for actionable diagnostics.
            if ($null -eq $code) {
                Write-Host "`nGitHub API base URI '$ApiBaseUri' is not reachable (no response) while probing membership for '$($user.login)' in '$Organization'." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiBaseUriFailed' }
                return
            }
            if ($code -ge 500 -and $code -le 599) {
                Write-Host "`nGitHub API request failed (HTTP $code) while probing membership for '$($user.login)' in '$Organization'. Service may be temporarily unavailable; check https://www.githubstatus.com/ and retry." -ForegroundColor Red
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'ApiUnavailable' }
                return
            }
            if ($authenticationType -eq 'GitHubAppDeviceFlow' -and -not $orgInstallPrompted -and $code -eq 403) {
                $orgInstallPrompted = Request-MtGitHubAppOrganizationInstall -Organization $Organization -InstallUrl $maesterGitHubAppInstallUrl -Reason $apiMsg
                if ($orgInstallPrompted) {
                    continue
                }
            }
            $msg = switch ($code) {
                403     { "Membership probe forbidden (403). The token cannot prove membership in '$Organization'. For Maester GitHub App auth, confirm the app is installed/approved for '$Organization' ($maesterGitHubAppInstallUrl) and that '$($user.login)' is an active organization member. GitHub API: $apiMsg" }
                404     { "The signed-in user '$($user.login)' is not an active member of organization '$Organization' (404). GitHub API: $apiMsg" }
                default { "Membership probe failed (HTTP $code). $apiMsg" }
            }
            Write-Host "`nFailed to verify GitHub organization membership: $msg" -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipFailed' }
            return
        }

        break
    }

    # Probe 4: organization administration access (non-blocking).
    # /orgs/{org}/actions/permissions requires classic PAT 'admin:org' or fine-grained
    # 'Organization Administration: read' — a closer match to the permissions needed by
    # CIS org-admin controls than the membership endpoint. Failure here records the
    # outcome and emits a warning, but does not flip Connected to $false.
    $adminVerified           = $false
    $adminFailureReason      = $null
    $adminStatusCode         = $null
    $adminAcceptedPermissions = $null
    $adminWarning            = $null
    try {
        $adminResponse = Invoke-WebRequest -Uri "$ApiBaseUri/orgs/$encodedOrg/actions/permissions" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop
        $adminVerified   = $true
        $adminStatusCode = 200
        if ($adminResponse.PSObject.Properties.Name -contains 'StatusCode' -and $null -ne $adminResponse.StatusCode) {
            $adminStatusCode = [int]$adminResponse.StatusCode
        }
    } catch {
        $adminStatusCode    = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        $adminApiMsg        = Get-MtGitHubErrorMessage    -ErrorRecord $_
        $respHeaders        = $null
        if ($null -ne $_.Exception -and $null -ne $_.Exception.Response) {
            $respHeaders = $_.Exception.Response.Headers
        }
        $adminAcceptedPermissions = Get-MtGitHubResponseHeaderValue -Headers $respHeaders -Name 'x-accepted-github-permissions'
        $adminRateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
        if ($adminRateLimitMessage) {
            $adminFailureReason = $adminRateLimitMessage
            $adminWarning = "GitHub organization administration API access was not verified due to a GitHub API rate limit. Detail: $adminRateLimitMessage"
        } else {
            $adminFailureReason = switch ($adminStatusCode) {
                403     { "HTTP 403 from /orgs/$Organization/actions/permissions. $adminApiMsg" }
                404     { "HTTP 404 from /orgs/$Organization/actions/permissions. $adminApiMsg" }
                default { "HTTP $adminStatusCode from /orgs/$Organization/actions/permissions. $adminApiMsg" }
            }
            $adminWarning = "GitHub organization administration API access was not verified. Some CIS controls requiring org administration may skip or report limited visibility. Required permissions — Maester GitHub App: Organization Administration: read; classic PAT: admin:org; fine-grained PAT: Organization Administration: read. Detail: $adminFailureReason"
        }
    }

    $__MtSession.GitHubAuthHeader = $authHeaders
    $__MtSession.GitHubConnection = [PSCustomObject]@{
        Connected                                   = $true
        Organization                                = $Organization
        ApiBaseUri                                  = $ApiBaseUri
        ApiVersion                                  = $ApiVersion
        TokenLogin                                  = $user.login
        Plan                                        = $planName
        Role                                        = $role
        RoleState                                   = $roleState
        RoleVerified                                = $true
        RoleVerificationFailureReason               = $null
        AuthenticationType                          = $authenticationType
        TokenExpiresAt                              = $tokenExpiresAt
        AdministrationPermissionVerified            = $adminVerified
        AdministrationPermissionFailureReason       = $adminFailureReason
        AdministrationPermissionStatusCode          = $adminStatusCode
        AdministrationPermissionAcceptedPermissions = $adminAcceptedPermissions
        FailureReason                               = $null
    }

    if ($roleWarning)  { Write-Warning $roleWarning }
    if ($adminWarning) { Write-Warning $adminWarning }

    $planDisplay = if ($planName) { " (plan: $planName)" } else { '' }
    Write-Host "Connected to GitHub organization '$($orgData.login)' as '$($user.login)'$planDisplay." -ForegroundColor Green
}
