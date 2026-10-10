function Write-MtConsoleLine {
    <#
    .SYNOPSIS
    Writes a line to the host without disturbing the console renderer of an interactive run.

    .DESCRIPTION
    The line goes through Write-Host, so it reaches the information stream and transcripts. Pass colour as
    ANSI sequences in the text (see Get-MtConsoleMode).

    While the renderer shows its compact region or status line, the region is erased around the write. While
    the full-screen dashboard owns the screen there is no scrollback to write to: the line is kept and written
    by Stop-MtConsoleOutput once the screen is restored.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output, as Pester writes it')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Text
    )

    $renderer = $script:__MtConsoleRenderer
    if ($renderer -and $renderer.IsFullScreen) {
        Add-MtDeferredOutput -Line $Text
    } elseif ($renderer) {
        $renderer.Pause()
        try { Write-Host $Text } finally { $renderer.Resume() }
    } else {
        Write-Host $Text
    }
}

function Add-MtDeferredOutput {
    <#
    .SYNOPSIS
    Keeps host output for after the full-screen dashboard: a line, or the records a test wrote.
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [AllowEmptyString()] [string] $Line,
        # A Maester.Engine.MtRunResult whose warning, verbose, debug and information records were not replayed.
        [Parameter()] [object] $RunResult
    )
    if (-not $script:__MtDeferredOutput) { $script:__MtDeferredOutput = [System.Collections.Generic.List[object]]::new() }
    if ($RunResult) { $script:__MtDeferredOutput.Add($RunResult) }
    elseif ($PSBoundParameters.ContainsKey('Line')) { $script:__MtDeferredOutput.Add([string]$Line) }
}

function New-MtConsoleRenderer {
    <#
    .SYNOPSIS
    Creates the console renderer of an interactive run and makes it the session's renderer.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([Maester.Engine.MtConsoleRenderer])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Console,
        # Use the full-screen dashboard when the console is large enough.
        [Parameter()] [switch] $FullScreen
    )
    $renderer = [Maester.Engine.MtConsoleRenderer]::new()
    $renderer.Ansi = $Console.Ansi
    $renderer.Unicode = $Console.Unicode
    $renderer.TrueColor = $Console.ColorDepth -eq 'TrueColor'
    $renderer.TaskbarProgress = $Console.Taskbar
    $renderer.FullScreen = $FullScreen.IsPresent
    $script:__MtConsoleRenderer = $renderer
    $script:__MtDeferredOutput = [System.Collections.Generic.List[object]]::new()
    $renderer
}

function Stop-MtConsoleOutput {
    <#
    .SYNOPSIS
    Ends the console renderer of an interactive run: restores the screen and the cursor, then writes what was kept.

    .DESCRIPTION
    Safe to call more than once. The lines and test records that were kept while the full-screen dashboard
    owned the screen are written in order: lines through Write-Host, records on their own streams.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Restores the console only.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output, as Pester writes it')]
    [CmdletBinding()]
    param()
    if ($script:__MtConsoleRenderer) {
        try { $script:__MtConsoleRenderer.Close() } catch { Write-Debug "Console renderer close failed: $_" }
        $script:__MtConsoleRenderer = $null
    }
    $deferred = $script:__MtDeferredOutput
    $script:__MtDeferredOutput = $null
    foreach ($item in @($deferred)) {
        if ($null -eq $item) { continue }
        if ($item -is [string]) { Write-Host $item; continue }
        foreach ($record in $item.Warnings) { Write-Warning $record.Message }
        foreach ($record in $item.Verbose) { Write-Verbose $record.Message }
        foreach ($record in $item.Debug) { Write-Debug $record.Message }
        foreach ($record in $item.Information) { $PSCmdlet.WriteInformation($record) }
    }
}

function Set-MtConsolePhase {
    <#
    .SYNOPSIS
    Tells the console renderer of an interactive run which phase the run is in: Prepare, Run tests, Results or Reports.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates the console display only.')]
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)] [string] $Name)
    if ($script:__MtConsoleRenderer) { $script:__MtConsoleRenderer.StartPhase($Name) }
}

function Initialize-MtDashboard {
    <#
    .SYNOPSIS
    Sets up the panels of the dashboard of an interactive run, and opens it.

    .DESCRIPTION
    The panels and their order come from Output.DashboardPanels in the run config; the default is all of
    them. Results is the chart under the lanes; the others stack in a column on the right when the console
    is wide enough (about 140 columns).

      Connections  the services of the run, and which of them are connected (set later, by Invoke-Maester)
      Tenant    the tenant, its primary domain, the account and its object counts (set later, by Set-MtDashboardTenant)
      Failed    failed tests by severity
      Drift     changes against the newest earlier results file in the output folder, for the same tenant
      Pace      tests per second and the slowest tests
      Blog      the newest post on maester.dev (one web request, cached for a day)
      Version   not a panel: a newer Maester on the PowerShell Gallery is mentioned under the logo, as a link
                (one web request)
      Tips      a tip from assets/ConsoleTips.txt
      Results   one square per test

    Blog and Version are the only ones that use the network. They run on background threads, only when the
    dashboard is wide enough to show them, and never with -SkipVersionCheck.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Maester.Engine.MtConsoleRenderer] $Renderer,
        [Parameter(Mandatory)] [pscustomobject] $Console,
        [Parameter()] [AllowNull()] [pscustomobject] $RunConfig,
        # The results JSON file this run writes: the Drift panel looks for earlier results next to it.
        [Parameter()] [string] $OutputJsonFile,
        [Parameter()] [switch] $SkipVersionCheck
    )

    $known = 'Tenant', 'Connections', 'Failed', 'Drift', 'Pace', 'Blog', 'Version', 'Tips', 'Results'
    $panels = $known
    $output = if ($RunConfig -and $RunConfig.PSObject.Properties['Output']) { $RunConfig.Output } else { $null }
    if ($output -and $output.PSObject.Properties['DashboardPanels']) {
        $panels = @($output.DashboardPanels | Where-Object { $_ })
        $unknown = @($panels | Where-Object { $_ -notin $known })
        if ($unknown.Count -gt 0) { Write-Warning "Output.DashboardPanels: unknown panel$(if ($unknown.Count -gt 1) { 's' }) $($unknown -join ', '). The panels are $($known -join ', ')." }
        $panels = @($panels | Where-Object { $_ -in $known })
    }
    $Renderer.SetPanels([string[]]$panels)

    if ($panels -contains 'Tips') {
        $tipsFile = Join-Path $PSScriptRoot '../../assets/ConsoleTips.txt'
        if (Test-Path -LiteralPath $tipsFile) {
            # One tip per line, optionally followed by " | " and the address of a page that says more.
            $tips = [System.Collections.Generic.List[string]]::new()
            $links = [System.Collections.Generic.List[string]]::new()
            foreach ($line in Get-Content -LiteralPath $tipsFile | Where-Object { $_.Trim() }) {
                $text, $link = $line -split '\s+\|\s+(?=https://)', 2
                $tips.Add($text.Trim())
                $links.Add([string]$link)
            }
            $Renderer.SetTips($tips.ToArray(), $links.ToArray())
        }
    }

    # The status bar on the last row: where to read more about the project, each a hyperlink.
    # The first four are at the left of the bar and the last four at its right edge.
    $heart = if ($Console -and $Console.Unicode) { [string][char]0x2665 + ' ' } else { '' }
    $bar = [ordered]@{
        'maester.dev'           = 'https://maester.dev'
        'Docs'                  = 'https://maester.dev/docs'
        'Contributors'          = 'https://maester.dev/contributors'
        'Our Manifesto'         = 'https://maester.cloud/manifesto'
        'Star on GitHub'        = 'https://github.com/maester365/maester'
        'Discord'               = 'https://discord.maester.dev'
        'Issues'                = 'https://github.com/maester365/maester/issues'
        "${heart}Sponsor"       = 'https://github.com/maester365/maester?sponsor=1'
    }
    $Renderer.SetStatusBar([string[]]@($bar.Keys), [string[]]@($bar.Values), 4)
    # Terminals open a hyperlink on a click with a modifier key: say which.
    $modifier = if (-not $IsMacOS) { 'Ctrl' } elseif ($Console -and $Console.Unicode) { [string][char]0x2318 } else { 'Cmd' }
    $Renderer.SetStatusBarHint("$modifier-click to open")

    $Renderer.Open()
    if (-not $Renderer.IsFullScreen) { return }

    if ($panels -contains 'Drift' -and $OutputJsonFile) {
        $folder = Split-Path -Path $OutputJsonFile -Parent
        $current = Split-Path -Path $OutputJsonFile -Leaf
        $previous = Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $current -and $_.Name -notlike '*-affected-objects.json' -and $_.Length -gt 0 } |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($previous) {
            $tenantId = try { [string](Get-MgContext).TenantId } catch { $null }
            # The HTML report of that run, written next to its results: the date in the panel opens it.
            $report = [System.IO.Path]::ChangeExtension($previous.FullName, '.html')
            $reportUrl = if (Test-Path -LiteralPath $report -PathType Leaf) { [System.Uri]::new($report).AbsoluteUri } else { $null }
            $null = $Renderer.LoadBaselineAsync($previous.FullName, $tenantId, $reportUrl)
        }
    }

    # What comes from the web, never with -SkipVersionCheck: the newest blog post when the right column can be
    # shown, and a newer version, which the banner mentions, when the console is wide enough for the banner.
    if (-not $SkipVersionCheck) {
        if ($panels -contains 'Blog' -and $Console.Width -ge 140) {
            $cache = Join-Path ([System.Environment]::GetFolderPath('LocalApplicationData')) 'Maester/blog-posts.txt'
            $null = [Maester.Engine.MtConsoleFeeds]::StartBlog($Renderer, 'https://maester.dev/blog/rss.xml', $cache, 3)
        }
        if ($panels -contains 'Version' -and $Console.Width -ge 90) {
            $null = [Maester.Engine.MtConsoleFeeds]::StartVersion($Renderer, 'Maester', [string](Get-MtModuleVersion))
        }
    }
}

function Get-MtDashboardTenantCount {
    <#
    .SYNOPSIS
    Counts the users, guests, devices, groups, apps and agents of the tenant, for the Tenant panel.

    .DESCRIPTION
    One Graph batch request with six $count queries, so one round trip. A count that cannot be read (a missing
    permission, a tenant without the feature) is left out; when the request itself fails there are none.
    Returns an ordered dictionary of label to count.

    A run of fewer than ten tests is over in a moment, and the request would be a large part of it: such a run
    makes no request and has no counts.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        # How many tests the run is going to run.
        [Parameter()] [int] $TestCount = [int]::MaxValue
    )
    if ($TestCount -lt 10) { return [ordered]@{} }

    $queries = [ordered]@{
        Users   = 'users/$count'
        Guests  = "users/`$count?`$filter=userType eq 'Guest'"
        Devices = 'devices/$count'
        Groups  = 'groups/$count'
        Apps    = 'applications/$count'
        Agents  = 'servicePrincipals/microsoft.graph.agentIdentity/$count'
    }
    $counts = [ordered]@{}
    try {
        $requests = foreach ($name in $queries.Keys) {
            @{ id = $name; method = 'GET'; url = $queries[$name]; headers = @{ ConsistencyLevel = 'eventual' } }
        }
        $body = @{ requests = @($requests) } | ConvertTo-Json -Depth 5
        $response = Invoke-MgGraphRequest -Method POST -Uri '/v1.0/$batch' -Body $body -ContentType 'application/json' -OutputType PSObject -ErrorAction Stop
        $byId = @{}
        foreach ($item in @($response.responses)) { $byId[[string]$item.id] = $item }
        foreach ($name in $queries.Keys) {
            $item = $byId[$name]
            if (-not $item -or [int]$item.status -ne 200) { continue }
            # A count comes back as a number, as text, or as base64 text, depending on the service.
            $value = 0L
            $text = [string]$item.body
            if (-not [long]::TryParse($text, [ref]$value)) {
                try { $text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($text)).Trim([char]0xFEFF, ' ') } catch { continue }
                if (-not [long]::TryParse($text, [ref]$value)) { continue }
            }
            $counts[$name] = $value
        }
    } catch {
        Write-Verbose "Could not count the objects of the tenant: $($_.Exception.Message)"
    }
    $counts
}

function Set-MtDashboardTenant {
    <#
    .SYNOPSIS
    Fills the Tenant panel of the dashboard: the tenant and its primary domain, the account, and how many
    users, guests, devices, groups, apps and agents it has.

    .DESCRIPTION
    Without a Graph connection (or with -SkipGraphConnect) there is no tenant to show, and the panel says so.
    The connected services are not here: they are the line under the banner.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates the console display only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Maester.Engine.MtConsoleRenderer] $Renderer,
        [Parameter()] [AllowNull()] [pscustomobject] $TenantContext,
        # From Get-MtDashboardTenantCount: label to count.
        [Parameter()] [AllowNull()] [System.Collections.IDictionary] $Count,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    $graph = $TenantContext -and $TenantContext.Services -and $TenantContext.Services.PSObject.Properties['Graph'] -and $TenantContext.Services.Graph
    if (-not $graph) {
        $Renderer.SetPanelText('Tenant', 'Tenant', [string[]]@(Format-MtConsoleText 'Not connected to Microsoft Graph' -Style Dim -Console $Console))
        return
    }
    $domain = if ($TenantContext.PSObject.Properties['PrimaryDomain']) { [string]$TenantContext.PrimaryDomain } else { '' }
    $account = @($TenantContext.Account, $TenantContext.AuthType | Where-Object { $_ }) -join ' · '
    $labels = [System.Collections.Generic.List[string]]::new()
    $values = [System.Collections.Generic.List[string]]::new()
    if ($Count) {
        foreach ($label in $Count.Keys) {
            $labels.Add([string]$label)
            $values.Add((Format-MtCompactNumber ([long]$Count[$label])))
        }
    }
    $Renderer.SetTenant([string]$TenantContext.TenantName, $domain, $account, $labels.ToArray(), $values.ToArray())
}
