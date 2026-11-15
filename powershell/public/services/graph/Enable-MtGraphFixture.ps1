function Enable-MtGraphFixture {
    <#
    .SYNOPSIS
    Turns on Graph record or replay: record Microsoft Graph responses to a fixture set, or answer requests from one with no network.

    .DESCRIPTION
    Graph record and replay lets you write and run Maester tests without a tenant, for example on a plane, and gives
    every test mock data with a known result.

    Record: requests go to Microsoft Graph as usual, and every response, including 403 and 404 errors, is also
    written to the fixture set as a JSON file. Responses are sanitised by default: tenant ID, object IDs, user
    principal names, email addresses, domain names, display names and personal fields are replaced with stable fake
    values. Tokens and headers are never written. Connect to a test tenant with Connect-Maester first.

    Replay: no request is sent. Responses come from the fixture set, and recorded errors are thrown as Graph threw
    them. No Connect-Maester or Connect-MgGraph is needed: inside Maester, Get-MgContext returns the connection the
    fixture set was recorded with. A request with no fixture fails with an error that names it, and is listed by
    Get-MtGraphFixtureStatus and at the end of Invoke-Maester. Tests that need another service (Exchange Online,
    Teams, Security & Compliance, Azure and the others) are skipped, because only Microsoft Graph is recorded.

    A fixture set is a folder, <Path>/<Scenario>: scenario.json (the connection and the expected test results),
    index.json (every request and its file) and graph/ (one file per request). Keep several scenarios side by side,
    such as well-configured, badly-configured and empty, so that each test has a known passing and failing case.

    The mode lasts for the PowerShell session, until Disable-MtGraphFixture. Invoke-Maester and Invoke-MtTest also
    turn it on from environment variables: MAESTER_GRAPH_FIXTURE_MODE (Record or Replay), MAESTER_GRAPH_FIXTURE_PATH,
    MAESTER_GRAPH_FIXTURE_SCENARIO and, to record without sanitising, MAESTER_GRAPH_FIXTURE_SANITIZE=0.

    .PARAMETER Mode
    Record writes the responses of a connected tenant to the fixture set. Replay answers requests from it.

    .PARAMETER Path
    The folder that holds the fixture sets, one subfolder per scenario. Created when recording.

    .PARAMETER Scenario
    The name of the fixture set: lowercase letters, digits and hyphens. Defaults to default.

    .PARAMETER NoSanitize
    Record the responses as Graph returned them. Use only for a fixture set that never leaves your computer.

    .PARAMETER PreserveValue
    GUIDs that sanitisation must keep, in addition to those in Maester's source (role template IDs, Microsoft
    application and permission IDs, licence IDs).

    .PARAMETER Description
    What the scenario is, written to its scenario.json when recording.

    .EXAMPLE
    ```powershell
    Connect-Maester
    Enable-MtGraphFixture -Mode Record -Path ./fixtures -Scenario contoso-dev
    Invoke-Maester -NonInteractive
    Disable-MtGraphFixture
    ```

    Records every Graph response of a full Maester run against a test tenant, sanitised, to ./fixtures/contoso-dev.

    .EXAMPLE
    ```powershell
    Enable-MtGraphFixture -Mode Replay -Path ./fixtures -Scenario contoso-dev
    Invoke-Maester -NonInteractive
    Get-MtGraphFixtureStatus
    ```

    Runs Maester offline against the recorded fixture set, then lists any request that had no fixture.

    .EXAMPLE
    ```powershell
    Enable-MtGraphFixture -Mode Replay -Path ./powershell/tests/fixtures/graph-replay -Scenario badly-configured
    Invoke-MtTest -Id MT.1073
    ```

    Runs one test against the badly configured fixture set that ships with Maester's unit tests.

    .LINK
    https://maester.dev/docs/commands/Enable-MtGraphFixture
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Record', 'Replay')]
        [string] $Mode,

        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [ValidatePattern('^[a-z0-9][a-z0-9.-]*$')]
        [string] $Scenario = 'default',

        [Parameter()]
        [switch] $NoSanitize,

        [Parameter()]
        [string[]] $PreserveValue,

        [Parameter()]
        [string] $Description
    )

    if ($__MtSession.GraphFixture) { $null = Disable-MtGraphFixture }
    # Responses cached from the tenant, or from another fixture set, must not answer requests of this one.
    Clear-MtGraphCache

    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $folder = Join-Path $root $Scenario
    $scenarioFile = Join-Path $folder 'scenario.json'
    $scenarioData = if (Test-Path -LiteralPath $scenarioFile -PathType Leaf) { Get-Content -LiteralPath $scenarioFile -Raw | ConvertFrom-Json } else { $null }

    $state = @{
        Mode         = $Mode
        Path         = $root
        Name         = $Scenario
        Folder       = $folder
        Scenario     = $scenarioData
        Sanitize     = -not $NoSanitize
        Missing      = [ordered]@{}
        Unsupported  = [ordered]@{}
        Served       = 0
        Recorded     = 0
        NextLinks    = [System.Collections.Generic.Dictionary[string, string]]::new()
        Context      = $null
        Source       = 'Command'
    }

    if ($Mode -eq 'Replay') {
        if (-not (Test-Path -LiteralPath (Join-Path $folder 'graph') -PathType Container) -and -not $scenarioData) {
            throw "There is no Graph fixture set '$Scenario' in '$root'. Record one with Enable-MtGraphFixture -Mode Record, or check -Path and -Scenario."
        }
        $__MtSession.GraphFixture = $state
        # Inside Maester, Get-MgContext reports the recorded connection: Test-MtConnection, Test-MtContext and the
        # checks that read the tenant ID, scopes or auth type need no Connect-MgGraph session.
        Set-Item -Path 'function:script:Get-MgContext' -Value {
            [CmdletBinding()]
            param()
            Get-MtGraphFixtureContext
        }
        # A direct Invoke-MgGraphRequest call (one that does not go through Invoke-MtGraphRequest) cannot be replayed.
        # In a native test it skips the test, with the engine's own skip (Add-MtTestResultDetail), which a catch block
        # in the test cannot turn into an error; anywhere else it throws. It never tries to reach Graph.
        Set-Item -Path 'function:script:Invoke-MgGraphRequest' -Value {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0)] [string] $Method = 'GET',
                [Parameter(Position = 1)] [object] $Uri,
                [Parameter(ValueFromRemainingArguments)] [object[]] $RemainingArguments
            )
            if ($__MtSession.GraphFixture) { $__MtSession.GraphFixture.Unsupported["$Method $Uri"] = [pscustomobject]@{ Method = $Method; Uri = "$Uri" } }
            $unsupported = New-MtGraphFixtureError -Unsupported -Method $Method -Uri "$Uri"
            if (-not [string]::IsNullOrEmpty([Maester.Engine.MtSession]::GetCurrentTest())) {
                Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $unsupported.Exception.Message
            }
            $PSCmdlet.ThrowTerminatingError($unsupported)
        }
        Write-Verbose "Graph replay is on: responses come from '$folder'. No request is sent to Microsoft Graph."
        return Get-MtGraphFixtureStatus
    }

    # Record. Any replay of the session was turned off above, so these are the Graph SDK's own commands.
    $context = Get-MgContext
    if (-not $context) {
        throw "Recording needs a connection to the tenant to record from. Run Connect-Maester first, then Enable-MtGraphFixture -Mode Record."
    }
    $null = New-Item -Path (Join-Path $folder 'graph') -ItemType Directory -Force

    if ($state.Sanitize) {
        # The salt makes fake values impossible to match to real ones without it. It stays on this computer:
        # anyone with it could check a guessed tenant ID against the fixture set.
        $saltFile = Join-Path $folder '.salt'
        $salt = if ($env:MAESTER_GRAPH_FIXTURE_SALT) { $env:MAESTER_GRAPH_FIXTURE_SALT } elseif (Test-Path -LiteralPath $saltFile -PathType Leaf) { (Get-Content -LiteralPath $saltFile -Raw).Trim() } else { $null }
        if (-not $salt) {
            $salt = [System.Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
            [System.IO.File]::WriteAllText($saltFile, $salt, [System.Text.UTF8Encoding]::new($false))
        }
        $gitIgnore = Join-Path $folder '.gitignore'
        if (-not (Test-Path -LiteralPath $gitIgnore -PathType Leaf)) {
            [System.IO.File]::WriteAllText($gitIgnore, ".salt`n", [System.Text.UTF8Encoding]::new($false))
        }
        $wellKnown = [System.Collections.Generic.HashSet[string]]::new([System.Collections.Generic.IEnumerable[string]](Get-MtGraphFixtureWellKnownId), [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($value in @($PreserveValue)) { if ($value) { $null = $wellKnown.Add($value) } }
        $state.Salt = $salt
        $state.WellKnownIds = $wellKnown
        $state.Domains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $state.DisplayNames = [System.Collections.Generic.Dictionary[string, string]]::new()

        # The tenant's domains are learnt from the responses; reading them first means a domain is replaced even in
        # a response that comes before the first one that lists it. This request is not recorded.
        try {
            $organization = Invoke-MgGraphRequest -Method GET -Uri 'v1.0/organization?$select=verifiedDomains' -OutputType PSObject -ErrorAction Stop
            foreach ($domain in @($organization.value.verifiedDomains)) { if ($domain.name) { $null = $state.Domains.Add([string]$domain.name) } }
        } catch {
            Write-Verbose "The tenant's domains could not be read before recording; they are learnt from the responses instead: $($_.Exception.Message)"
        }
    }

    # scenario.json: what the scenario is, the connection it was recorded with and the expected test results.
    $protectText = { param($text) if ($state.Sanitize -and $text) { Protect-MtGraphFixtureData -Text ([string]$text) -State $state } else { [string]$text } }
    $data = [ordered]@{
        name         = $Scenario
        description  = if ($Description) { $Description } elseif ($scenarioData -and $scenarioData.description) { [string]$scenarioData.description } else { "Recorded with Maester $(Get-MtModuleVersion)." }
        sanitized    = [bool]$state.Sanitize
        context      = [ordered]@{
            tenantId    = & $protectText $context.TenantId
            account     = & $protectText $context.Account
            authType    = [string]$context.AuthType
            clientId    = & $protectText $context.ClientId
            environment = [string]$context.Environment
            scopes      = @($context.Scopes | Sort-Object -Unique)
        }
        expectations = if ($scenarioData -and $scenarioData.expectations) { $scenarioData.expectations } else { [ordered]@{} }
    }
    $json = (ConvertTo-MtGraphFixtureJson -Json (ConvertTo-Json -InputObject $data -Depth 10)) + "`n"
    [System.IO.File]::WriteAllText($scenarioFile, $json, [System.Text.UTF8Encoding]::new($false))
    $state.Scenario = $json | ConvertFrom-Json

    $__MtSession.GraphFixture = $state
    Write-Verbose "Graph recording is on: responses are written to '$folder'$(if (-not $state.Sanitize) { ' without sanitising' })."
    return Get-MtGraphFixtureStatus
}
