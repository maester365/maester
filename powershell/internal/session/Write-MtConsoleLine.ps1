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

      Tenant    the tenant, its ID, the account and the cloud (set later, by Set-MtDashboardTenant)
      Failed    failed tests by severity
      Drift     changes against the newest earlier results file in the output folder, for the same tenant
      Pace      tests per second and the slowest tests
      Blog      the newest posts on maester.dev (one web request, cached for a day)
      Version   whether a newer Maester is on the PowerShell Gallery (one web request)
      Tips      a tip from assets/ConsoleTips.txt
      Results   one square per test

    Blog and Version are the only panels that use the network. They run on background threads, only when the
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

    $known = 'Tenant', 'Failed', 'Drift', 'Pace', 'Blog', 'Version', 'Tips', 'Results'
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
        if (Test-Path -LiteralPath $tipsFile) { $Renderer.SetTips([string[]]@(Get-Content -LiteralPath $tipsFile | Where-Object { $_.Trim() })) }
    }

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
            $null = $Renderer.LoadBaselineAsync($previous.FullName, $tenantId)
        }
    }

    # The network panels: only when the right column can be shown, and never with -SkipVersionCheck.
    if (-not $SkipVersionCheck -and $Console.Width -ge 140) {
        if ($panels -contains 'Blog') {
            $cache = Join-Path ([System.Environment]::GetFolderPath('LocalApplicationData')) 'Maester/blog-posts.txt'
            $null = [Maester.Engine.MtConsoleFeeds]::StartBlog($Renderer, 'https://maester.dev/blog/rss.xml', $cache, 3)
        }
        if ($panels -contains 'Version') {
            $null = [Maester.Engine.MtConsoleFeeds]::StartVersion($Renderer, 'Maester', [string](Get-MtModuleVersion))
        }
    }
}

function Set-MtDashboardTenant {
    <#
    .SYNOPSIS
    Fills the Tenant panel of the dashboard: the tenant, its ID, the account and the cloud.

    .DESCRIPTION
    Without a Graph connection (or with -SkipGraphConnect) there is no tenant to show, and the panel says so.
    The connected services are not here: they are the line under the banner.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates the console display only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Maester.Engine.MtConsoleRenderer] $Renderer,
        [Parameter()] [AllowNull()] [pscustomobject] $TenantContext,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $graph = $TenantContext -and $TenantContext.Services -and $TenantContext.Services.PSObject.Properties['Graph'] -and $TenantContext.Services.Graph
    if ($graph) {
        if ($TenantContext.TenantName) { $lines.Add((Format-MtConsoleText ([string]$TenantContext.TenantName) -Style Bold -Console $Console)) }
        if ($TenantContext.TenantId) { $lines.Add((Format-MtConsoleText ([string]$TenantContext.TenantId) -Style Dim -Console $Console)) }
        $account = @($TenantContext.Account, $TenantContext.AuthType | Where-Object { $_ }) -join ' · '
        if ($account) { $lines.Add($account) }
        $kind = @($TenantContext.Cloud, $TenantContext.TenantType | Where-Object { $_ -and $_ -ne 'Unknown' }) -join ' · '
        if ($kind) { $lines.Add((Format-MtConsoleText $kind -Style Dim -Console $Console)) }
    } else {
        $lines.Add((Format-MtConsoleText 'Not connected to Microsoft Graph' -Style Dim -Console $Console))
    }
    $Renderer.SetPanelText('Tenant', 'Tenant', $lines.ToArray())
}
