function Connect-MtGitHub {
    <#
    .SYNOPSIS
    Connects to the GitHub REST API for Maester security testing.

    .DESCRIPTION
    Establishes a GitHub REST API session for Maester CIS GitHub Enterprise Cloud benchmark
    tests. Validates the PAT via three probes, all of which must succeed:
      1. GET /user                            — token identity
      2. GET /orgs/{org}                      — org metadata (login, plan)
      3. GET /orgs/{org}/memberships/{user}   — org-access proof (state + role)

    The membership probe is the real access gate: /orgs/{org} returns public metadata
    even for tokens with no relationship to the organization. A 4xx, malformed body,
    or missing state/role on probe 3 aborts with FailureReason = 'OrgMembershipFailed'.

    On success, Role = 'admin' + RoleState = 'active' is the no-warning path. Other
    valid roles (member, billing_manager, etc.) or 'pending' state still connect but
    emit a warning indicating limited CIS coverage.

    Token resolution order:
      1. -Token parameter (SecureString)
      2. MAESTER_GITHUB_TOKEN environment variable
      3. GH_TOKEN environment variable (GitHub CLI convention)

    Required permissions (classic PAT): admin:org
    Fine-grained PAT (expected; validate in integration testing):
      Organization Administration: read + Organization Members: read
    Required GitHub role: organization owner for full org settings visibility.

    Note: Connection success proves token validity and org access, not that all
    CIS control fields will be visible. Each CIS test validates field availability
    and skips with an informative message if required fields are absent.

    .PARAMETER Organization
    GitHub organization login name. Falls back to GitHubOrganization in maester-config.json.

    .PARAMETER Token
    PAT as SecureString. Falls back to MAESTER_GITHUB_TOKEN or GH_TOKEN env vars.

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
        [ValidatePattern('^https://')]
        [string] $ApiBaseUri,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
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

    # Resolve ApiBaseUri (param -> config -> default) into a local variable. Reassigning
    # $ApiBaseUri would re-trigger [ValidatePattern] and short-circuit the config path with
    # a hard exception instead of our InvalidApiBaseUri failure.
    $resolvedApiBaseUri = $ApiBaseUri
    if ([string]::IsNullOrWhiteSpace($resolvedApiBaseUri)) {
        $configApiBaseUri = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiBaseUri'
        if (-not [string]::IsNullOrWhiteSpace($configApiBaseUri)) { $resolvedApiBaseUri = $configApiBaseUri }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedApiBaseUri)) { $resolvedApiBaseUri = 'https://api.github.com' }
    $resolvedApiBaseUri = $resolvedApiBaseUri.TrimEnd('/')

    # Revalidate the fully-resolved URI. [ValidatePattern] on the param only fires when -ApiBaseUri
    # is bound, so a config value can otherwise reach Invoke-WebRequest with a Bearer header on http://.
    $parsedUri = $null
    if (-not [uri]::TryCreate($resolvedApiBaseUri, [UriKind]::Absolute, [ref]$parsedUri) -or $parsedUri.Scheme -cne 'https') {
        Write-Host "`nGitHub API base URI must be an absolute https:// URI. Got: '$resolvedApiBaseUri'." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'InvalidApiBaseUri' }
        return
    }
    $ApiBaseUri = $resolvedApiBaseUri

    # Resolve ApiVersion (param -> config -> default)
    # Use a local variable for the config lookup to avoid triggering [ValidatePattern] on $null.
    if ([string]::IsNullOrWhiteSpace($ApiVersion)) {
        $configApiVersion = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiVersion'
        if (-not [string]::IsNullOrWhiteSpace($configApiVersion)) { $ApiVersion = $configApiVersion }
    }
    if ([string]::IsNullOrWhiteSpace($ApiVersion)) { $ApiVersion = '2022-11-28' }

    # Resolve token (param -> MAESTER_GITHUB_TOKEN -> GH_TOKEN)
    $plainToken = $null
    $bstr = [IntPtr]::Zero
    try {
        if ($Token) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
            $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        } elseif (-not [string]::IsNullOrEmpty($env:MAESTER_GITHUB_TOKEN)) {
            $plainToken = $env:MAESTER_GITHUB_TOKEN
        } elseif (-not [string]::IsNullOrEmpty($env:GH_TOKEN)) {
            $plainToken = $env:GH_TOKEN
        }
    } finally {
        if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if ([string]::IsNullOrEmpty($plainToken)) {
        Write-Host "`nNo GitHub token found. Provide -Token, or set MAESTER_GITHUB_TOKEN or GH_TOKEN." -ForegroundColor Red
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
        $code = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        Write-Host "`nGitHub token validation failed (HTTP $code). Verify the PAT is valid and not expired." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'TokenInvalid' }
        return
    }

    # Probe 2: org access
    $encodedOrg = [System.Uri]::EscapeDataString($Organization)
    try {
        $orgResponse = Invoke-WebRequest -Uri "$ApiBaseUri/orgs/$encodedOrg" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop
        $orgData = $orgResponse.Content | ConvertFrom-Json
    } catch {
        $code = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        $apiMsg = Get-MtGitHubErrorMessage -ErrorRecord $_
        $msg = switch ($code) {
            403     { "Access denied (403). Verify the PAT has 'admin:org' scope and is used by an organization owner. GitHub API: $apiMsg" }
            404     { "Organization '$Organization' not found (404). Check the organization login name. GitHub API: $apiMsg" }
            default { "HTTP $code. $apiMsg" }
        }
        Write-Host "`nFailed to access GitHub organization: $msg" -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgAccessFailed' }
        return
    }

    # Null-safe plan name (not visible for all token types/roles)
    $planName = $null
    if ($orgData.PSObject.Properties.Name -contains 'plan' -and $null -ne $orgData.plan) {
        $planName = $orgData.plan.name
    }

    # Probe 3: org membership / role — blocking proof of org access.
    # /orgs/{org} returns public org metadata even for tokens with no relationship to the org,
    # so membership is the real access gate. Any failure here aborts the connection.
    $role         = $null
    $roleState    = $null
    $roleWarning  = $null

    $encodedLogin = [System.Uri]::EscapeDataString($user.login)
    try {
        $membershipResponse = Invoke-WebRequest -Uri "$ApiBaseUri/orgs/$encodedOrg/memberships/$encodedLogin" -Headers $authHeaders -Method GET -UseBasicParsing -ErrorAction Stop

        $membershipData = $null
        try {
            $membershipData = $membershipResponse.Content | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $membershipData = $null
        }

        $hasState = $null -ne $membershipData -and $membershipData.PSObject.Properties.Name -contains 'state' -and -not [string]::IsNullOrWhiteSpace([string]$membershipData.state)
        $hasRole  = $null -ne $membershipData -and $membershipData.PSObject.Properties.Name -contains 'role'  -and -not [string]::IsNullOrWhiteSpace([string]$membershipData.role)

        if (-not ($hasState -and $hasRole)) {
            Write-Host "`nGitHub organization membership could not be verified: malformed response from /orgs/$Organization/memberships/$($user.login)." -ForegroundColor Red
            $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipFailed' }
            return
        }

        $role      = [string]$membershipData.role
        $roleState = [string]$membershipData.state

        if ($roleState -eq 'active' -and $role -eq 'admin') {
            # No-warning path
        } elseif ($roleState -eq 'pending') {
            $roleWarning = "GitHub organization membership is pending acceptance. Some controls may report limited visibility until membership is accepted."
        } else {
            $roleWarning = "GitHub organization admin/owner permissions required for full CIS coverage. Current role: '$role'. Some controls may skip or report limited visibility."
        }
    } catch {
        $code   = Get-MtGitHubErrorStatusCode -ErrorRecord $_
        $apiMsg = Get-MtGitHubErrorMessage    -ErrorRecord $_
        $msg = switch ($code) {
            403     { "Membership probe forbidden (403). The token cannot prove membership in '$Organization'. GitHub API: $apiMsg" }
            404     { "User '$($user.login)' is not a member of organization '$Organization' (404). GitHub API: $apiMsg" }
            default { "Membership probe failed (HTTP $code). $apiMsg" }
        }
        Write-Host "`nFailed to verify GitHub organization membership: $msg" -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'OrgMembershipFailed' }
        return
    }

    $__MtSession.GitHubAuthHeader = $authHeaders
    $__MtSession.GitHubConnection = [PSCustomObject]@{
        Connected                     = $true
        Organization                  = $Organization
        ApiBaseUri                    = $ApiBaseUri
        ApiVersion                    = $ApiVersion
        TokenLogin                    = $user.login
        Plan                          = $planName
        Role                          = $role
        RoleState                     = $roleState
        RoleVerified                  = $true
        RoleVerificationFailureReason = $null
        FailureReason                 = $null
    }

    if ($roleWarning) {
        Write-Warning $roleWarning
    }

    $planDisplay = if ($planName) { " (plan: $planName)" } else { '' }
    Write-Host "Connected to GitHub organization '$($orgData.login)' as '$($user.login)'$planDisplay." -ForegroundColor Green
}
