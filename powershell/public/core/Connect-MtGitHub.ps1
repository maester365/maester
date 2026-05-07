function Connect-MtGitHub {
    <#
    .SYNOPSIS
    Connects to the GitHub REST API for Maester security testing.

    .DESCRIPTION
    Establishes a GitHub REST API session for Maester CIS GitHub Enterprise Cloud benchmark
    tests. Validates the PAT via GET /user (token identity) and GET /orgs/{org} (org access).

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

    # Resolve organization (param -> config -> error)
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        $Organization = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubOrganization'
    }
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        Write-Host "`nNo GitHub organization specified. Provide -Organization or set GitHubOrganization in maester-config.json." -ForegroundColor Red
        $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false; FailureReason = 'NotConfigured' }
        return
    }

    # Resolve ApiBaseUri (param -> config -> default)
    if ([string]::IsNullOrWhiteSpace($ApiBaseUri)) {
        $ApiBaseUri = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiBaseUri'
    }
    if ([string]::IsNullOrWhiteSpace($ApiBaseUri)) { $ApiBaseUri = 'https://api.github.com' }
    $ApiBaseUri = $ApiBaseUri.TrimEnd('/')

    # Resolve ApiVersion (param -> config -> default)
    if ([string]::IsNullOrWhiteSpace($ApiVersion)) {
        $ApiVersion = Get-MtMaesterConfigGlobalSetting -SettingName 'GitHubApiVersion'
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

    $__MtSession.GitHubAuthHeader = $authHeaders
    $__MtSession.GitHubConnection = [PSCustomObject]@{
        Connected     = $true
        Organization  = $Organization
        ApiBaseUri    = $ApiBaseUri
        ApiVersion    = $ApiVersion
        TokenLogin    = $user.login
        Plan          = $planName
        FailureReason = $null
    }

    $planDisplay = if ($planName) { " (plan: $planName)" } else { '' }
    Write-Host "Connected to GitHub organization '$($orgData.login)' as '$($user.login)'$planDisplay." -ForegroundColor Green
}
