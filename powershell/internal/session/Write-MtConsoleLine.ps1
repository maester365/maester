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
    param(
        # Warning and error records that Invoke-Maester collected while the dashboard was up. They are written
        # only if the full-screen dashboard owned the screen, where they were drawn over and lost.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $Message
    )
    $wasFullScreen = $false
    if ($script:__MtConsoleRenderer) {
        try { $wasFullScreen = [bool]$script:__MtConsoleRenderer.IsFullScreen } catch { Write-Debug "Console renderer state: $_" }
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
    if ($wasFullScreen) {
        # Write a record once, however often it was collected.
        $seen = [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
        foreach ($record in @($Message)) {
            if ($null -eq $record -or -not $seen.Add($record)) { continue }
            if ($record -is [System.Management.Automation.WarningRecord]) { Write-Warning $record.Message }
            elseif ($record -is [System.Management.Automation.ErrorRecord]) { $PSCmdlet.WriteError($record) }
        }
    }
}

function Get-MtDashboardMessageDefault {
    <#
    .SYNOPSIS
    The $PSDefaultParameterValues that collect the warnings and errors written while the full-screen dashboard owns the screen.

    .DESCRIPTION
    Adds a default for the -WarningVariable of Write-Warning and for the -ErrorVariable of Write-Error: the
    lists $mtDashboardWarnings and $mtDashboardErrors of Invoke-Maester, which must exist before the first
    message is written.

    Only those two commands, and only where the message would be shown. -WarningVariable and -ErrorVariable
    also receive what a command was told to keep quiet (-ErrorAction SilentlyContinue, as the check for a
    next page of every Graph request has), and a record does not say whether it was shown. A default for
    every command therefore wrote messages after the run that no run had shown. The price: a warning or
    error that another command writes while the dashboard is up is still drawn over.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # The defaults in effect, which are kept.
        [Parameter()] [AllowNull()] [System.Collections.IDictionary] $Default
    )
    $defaults = @{}
    if ($Default) { foreach ($key in @($Default.Keys)) { $defaults[$key] = $Default[$key] } }
    # A script block is run for each call, in the scope of the call: it sees the preference in effect there.
    # No value means no default.
    $defaults['Write-Warning:WarningVariable'] = { if ("$WarningPreference" -in 'Continue', 'Inquire') { '+mtDashboardWarnings' } }
    $defaults['Write-Error:ErrorVariable'] = { if ("$ErrorActionPreference" -in 'Continue', 'Inquire') { '+mtDashboardErrors' } }
    $defaults
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
    them. Pace, Results and the six insight panels are in the main column (the graph at the top, next to the
    logo; the blocks under the lanes; the insight panels under the list of tests, in rows of three); the
    others stack in a column on the right when the console is wide enough (about 140 columns). Every panel
    is shown when the column has the rows for it; the Slowest panel takes what is left over, and Blog, Tips
    and Contributor are at the bottom of the column.

    The insight panels count the results by the attributes of the tests (Set-MtDashboardTestInfo). A run of
    fewer than 25 tests has none of them, and a panel with nothing to show is left out. The second row of
    them needs a console of about 64 rows.

      Tenant       the tenant, its primary domain and the account (set later, by Set-MtDashboardTenant)
      Totals       the results so far: a bar split by result, and the count of each
      Connections  the services of the run, and which of them are connected (set later, by Invoke-Maester)
      Failed       failed tests by severity
      Slowest      the tests that took the longest: five, more in the rows that are left over
      Drift        changes against the newest earlier results file in the output folder, for the same tenant
      FixFirst     failed tests of severity Critical or High whose fix has a low user impact and a low cost
      Blog         the newest post on maester.dev (one web request, cached for a day)
      Version      not a panel: a newer Maester on the PowerShell Gallery is mentioned under the logo, as a link
                   (one web request)
      Tips         a tip from assets/ConsoleTips.txt
      Contributor  one of the people who built Maester, a different one every minute, from
                   assets/ConsoleContributors.json (written by build/Update-ConsoleContributors.ps1); the
                   last panel of the column, and the one with an accent border
      Pace         a graph of how long each test took, with the tests per second, at the top of the main
                   column next to the logo
      Results      one block per test, in the main column
      WeakestAreas   the areas with the lowest share of passed tests (first row of insight panels)
      AttackTactics  failed tests by MITRE ATT&CK tactic
      FailedTests    one dot per failed test, by the user impact and the cost of its fix
      NistFamilies   the NIST 800-53 control families with the lowest share of passed tests (second row)
      PassRate       the share of passed tests from the first test to now
      EveryTest      how long each test took, in the order the tests finished

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

    $known = 'Tenant', 'Totals', 'Connections', 'Failed', 'Slowest', 'Drift', 'FixFirst', 'Blog', 'Version', 'Tips', 'Contributor', 'Pace', 'Results',
    'WeakestAreas', 'AttackTactics', 'FailedTests', 'NistFamilies', 'PassRate', 'EveryTest'
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
        # One tip per line.
        if (Test-Path -LiteralPath $tipsFile) { $Renderer.SetTips([string[]]@(Get-Content -LiteralPath $tipsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ })) }
    }

    # The people who built Maester, from the list that ships with the module, starting with a different one each run.
    if ($panels -contains 'Contributor') {
        $contributorFile = Join-Path $PSScriptRoot '../../assets/ConsoleContributors.json'
        if (Test-Path -LiteralPath $contributorFile) { $null = $Renderer.LoadContributorsAsync($contributorFile, (Get-Random -Maximum 100000)) }
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
        # The newest results file in the folder. With a fixed -OutputJsonFile name that is the file this run
        # will replace: it still holds the previous run now, so it is the baseline too.
        $previous = Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '*-affected-objects.json' -and $_.Length -gt 0 } |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($previous) {
            $tenantId = try { [string](Get-MgContext).TenantId } catch { $null }
            # The HTML report of that run, written next to its results: the date in the panel opens it. Not
            # for a file this run replaces: its report is replaced as well.
            $report = [System.IO.Path]::ChangeExtension($previous.FullName, '.html')
            $reportUrl = if ($previous.Name -ne $current -and (Test-Path -LiteralPath $report -PathType Leaf)) { [System.Uri]::new($report).AbsoluteUri } else { $null }
            $null = $Renderer.LoadBaselineAsync($previous.FullName, $tenantId, $reportUrl)
        }
    }

    # What comes from the web, never with -SkipVersionCheck: the newest blog post when the right column can be
    # shown, and a newer version, which the banner mentions, when the console is wide enough for the banner.
    if (-not $SkipVersionCheck) {
        if ($panels -contains 'Blog' -and $Console.Width -ge 140) {
            # No such folder in some containers and service accounts: then the posts are not cached.
            $appData = [System.Environment]::GetFolderPath('LocalApplicationData')
            $cache = if ($appData) { Join-Path $appData 'Maester/blog-posts.txt' } else { $null }
            $null = [Maester.Engine.MtConsoleFeeds]::StartBlog($Renderer, 'https://maester.dev/blog/rss.xml', $cache, 3)
        }
        if ($panels -contains 'Version' -and $Console.Width -ge 90) {
            $null = [Maester.Engine.MtConsoleFeeds]::StartVersion($Renderer, 'Maester', [string](Get-MtModuleVersion))
        }
    }
}

function Set-MtDashboardTestInfo {
    <#
    .SYNOPSIS
    Gives the dashboard the attributes of the tests of the run, which its insight panels count the results by.

    .DESCRIPTION
    Called once, before the tests start: the area, severity, user impact, implementation cost, ATT&CK
    techniques and control references of each test, with the names the panels show (of the areas, of the
    tactic of each technique and of the NIST 800-53 control families). Nothing is looked up while tests run.

    A run of fewer than 25 tests has no insight panels, and neither has a console without the dashboard:
    then nothing is handed over.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates the console display only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Maester.Engine.MtConsoleRenderer] $Renderer,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [Maester.Engine.MtWorkItem[]] $WorkItem
    )
    if (-not $Renderer.IsFullScreen -or $WorkItem.Count -lt 25) { return }

    if (-not $script:__MtDashboardNames) {
        $areas = @{}
        foreach ($area in (Get-MtTaxonomy).Areas) { $areas[[string]$area.Key] = [string]$area.Name }
        # A technique that belongs to several tactics counts for the first.
        $attack = Get-MtAttackData
        $tactics = @{}
        foreach ($technique in $attack.TechniqueList) {
            $tactic = @($technique.Tactics)[0]
            if ($tactic -and $attack.Tactics.ContainsKey([string]$tactic)) { $tactics[[string]$technique.Id] = [string]$attack.Tactics[[string]$tactic].Name }
        }
        # The family of a control is the letters of its ID: AC-2 is in Access Control.
        $families = @{}
        $nistFile = Join-Path $PSScriptRoot '../../assets/MaesterNistControls.json'
        if (Test-Path -LiteralPath $nistFile) {
            foreach ($control in (Get-Content -LiteralPath $nistFile -Raw | ConvertFrom-Json).Controls) {
                $code = ([string]$control.Id -split '-')[0]
                if (-not $families.ContainsKey($code)) { $families[$code] = [string]$control.Family }
            }
        }
        $script:__MtDashboardNames = @{ Areas = $areas; Tactics = $tactics; Families = $families }
    }

    $info = [Maester.Engine.MtConsoleTestInfo[]]::new($WorkItem.Count)
    for ($i = 0; $i -lt $WorkItem.Count; $i++) {
        $test = $WorkItem[$i].Tag.PlanRow.Test
        $item = [Maester.Engine.MtConsoleTestInfo]::new()
        $item.Id = $WorkItem[$i].Id
        $item.Area = [string]$test.Area
        $item.Severity = [string]$test.Severity
        $item.UserImpact = [string]$test.UserImpact
        $item.ImplementationCost = [string]$test.ImplementationCost
        # No pipeline here: this runs for every test of the run. The renderer skips an empty entry.
        $item.Mitre = [string[]]@($test.Mitre)
        $item.Controls = [string[]]@($test.Control)
        $info[$i] = $item
    }
    $names = $script:__MtDashboardNames
    $Renderer.SetTestInfo($info, $names.Areas, $names.Tactics, $names.Families)
}

function Set-MtDashboardTenant {
    <#
    .SYNOPSIS
    Fills the Tenant panel of the dashboard: the tenant, its primary domain and the account.

    .DESCRIPTION
    Everything comes from the tenant context the run already has; nothing is requested for the panel.
    Without a Graph connection (or with -SkipGraphConnect) there is no tenant to show, and the panel says so.
    The connected services are not here: they are in the Connections panel.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates the console display only.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Maester.Engine.MtConsoleRenderer] $Renderer,
        [Parameter()] [AllowNull()] [pscustomobject] $TenantContext,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    $graph = $TenantContext -and $TenantContext.Services -and $TenantContext.Services.PSObject.Properties['Graph'] -and $TenantContext.Services.Graph
    if (-not $graph) {
        $Renderer.SetPanelText('Tenant', 'Tenant', [string[]]@(Format-MtConsoleText 'Not connected to Microsoft Graph' -Style Dim -Console $Console))
        return
    }
    $domain = if ($TenantContext.PSObject.Properties['PrimaryDomain']) { [string]$TenantContext.PrimaryDomain } else { '' }
    $account = @($TenantContext.Account, $TenantContext.AuthType | Where-Object { $_ }) -join ' · '
    $Renderer.SetTenant([string]$TenantContext.TenantName, $domain, $account)
}
