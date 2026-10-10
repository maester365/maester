BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Environment variables the detection reads; each test sets what it needs and the rest are cleared.
    $script:envNames = 'GITHUB_ACTIONS', 'TF_BUILD', 'CI', 'NO_COLOR', 'TERM', 'MAESTER_OUTPUT_MODE', 'COLORTERM', 'WT_SESSION', 'TERM_PROGRAM', 'TERM_PROGRAM_VERSION', 'ConEmuANSI', 'VTE_VERSION'
    $script:savedEnv = @{}
    foreach ($n in $script:envNames) { $script:savedEnv[$n] = [System.Environment]::GetEnvironmentVariable($n) }

    function Set-TestEnvironment {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([hashtable] $Values = @{})
        foreach ($n in $script:envNames) { [System.Environment]::SetEnvironmentVariable($n, $Values[$n]) }
    }

    $script:stream = [pscustomobject]@{ Mode = 'Stream'; CI = $null; Ansi = $false; Unicode = $true; ColorDepth = 'None'; Width = 120; Taskbar = $false; Hyperlink = $false }
}

AfterAll {
    foreach ($n in $script:envNames) { [System.Environment]::SetEnvironmentVariable($n, $script:savedEnv[$n]) }
}

Describe 'Get-MtConsoleMode' {
    AfterEach { Set-TestEnvironment }

    It 'Uses Stream in CI' {
        Set-TestEnvironment @{ GITHUB_ACTIONS = 'true' }
        $m = InModuleScope Maester { Get-MtConsoleMode }
        $m.Mode | Should -Be 'Stream'
        $m.CI | Should -Be 'GitHubActions'
    }

    It 'Detects Azure Pipelines' {
        Set-TestEnvironment @{ TF_BUILD = 'True' }
        (InModuleScope Maester { Get-MtConsoleMode }).CI | Should -Be 'AzureDevOps'
    }

    It 'Never uses Interactive with -NonInteractive' {
        Set-TestEnvironment
        (InModuleScope Maester { Get-MtConsoleMode -NonInteractive }).Mode | Should -Not -Be 'Interactive'
    }

    It 'Falls back to Stream when Interactive is asked for without a console it can draw on' {
        Set-TestEnvironment
        $m = InModuleScope Maester { Get-MtConsoleMode -Requested Interactive }
        if ([System.Console]::IsOutputRedirected -or $Host.Name -ne 'ConsoleHost' -or -not $Host.UI.SupportsVirtualTerminal) {
            $m.Mode | Should -Be 'Stream'
        } else {
            $m.Mode | Should -Be 'Interactive'
        }
    }

    It 'Honours MAESTER_OUTPUT_MODE' {
        Set-TestEnvironment @{ MAESTER_OUTPUT_MODE = 'Plain' }
        (InModuleScope Maester { Get-MtConsoleMode }).Mode | Should -Be 'Plain'
    }

    It 'Prefers -Requested over MAESTER_OUTPUT_MODE' {
        Set-TestEnvironment @{ MAESTER_OUTPUT_MODE = 'Plain' }
        (InModuleScope Maester { Get-MtConsoleMode -Requested Stream }).Mode | Should -Be 'Stream'
    }

    It 'Uses Plain without colour or Unicode for TERM=dumb' {
        Set-TestEnvironment @{ TERM = 'dumb' }
        $m = InModuleScope Maester { Get-MtConsoleMode }
        $m.Mode | Should -Be 'Plain'
        $m.Ansi | Should -BeFalse
        $m.Unicode | Should -BeFalse
    }

    It 'Turns colour off for NO_COLOR' {
        Set-TestEnvironment @{ NO_COLOR = '1'; GITHUB_ACTIONS = 'true' }
        (InModuleScope Maester { Get-MtConsoleMode }).Ansi | Should -BeFalse
    }

    It 'Keeps colour on GitHub Actions' {
        Set-TestEnvironment @{ GITHUB_ACTIONS = 'true' }
        (InModuleScope Maester { Get-MtConsoleMode }).Ansi | Should -BeTrue
    }

    It 'Never reports taskbar progress or hyperlinks outside Interactive' {
        Set-TestEnvironment @{ WT_SESSION = 'x'; GITHUB_ACTIONS = 'true' }
        $m = InModuleScope Maester { Get-MtConsoleMode }
        $m.Taskbar | Should -BeFalse
        $m.Hyperlink | Should -BeFalse
    }
}

Describe 'Console text helpers' {
    It 'Labels results with a symbol and the word in Unicode mode' {
        InModuleScope Maester -Parameters @{ c = $script:stream } {
            param($c)
            Format-MtResultLabel -Result 'Failed' -Console $c | Should -Be '✗ Failed'
            Format-MtResultLabel -Result 'Skipped' -Console $c | Should -Be '– Skipped'
        }
    }

    It 'Labels results with ASCII words in Plain mode' {
        $plain = $script:stream.PSObject.Copy(); $plain.Unicode = $false
        InModuleScope Maester -Parameters @{ c = $plain } {
            param($c)
            Format-MtResultLabel -Result 'Passed' -Console $c | Should -Be '[PASS]'
            Format-MtResultLabel -Result 'Investigate' -Console $c | Should -Be '[INVESTIGATE]'
        }
    }

    It 'Formats <Value> as <Expected>' -ForEach @(
        @{ Value = '00:00:00.120'; Expected = '120 ms' }
        @{ Value = '00:00:02.400'; Expected = '2.4 s' }
        @{ Value = '00:01:05'; Expected = '1:05' }
        @{ Value = '01:02:03'; Expected = '1:02:03' }
    ) {
        InModuleScope Maester -Parameters @{ v = $Value; e = $Expected } {
            param($v, $e)
            Format-MtDuration ([timespan]::Parse($v, [cultureinfo]::InvariantCulture)) | Should -Be $e
        }
    }

    It 'Adds colour only when the mode uses it' {
        $ansi = $script:stream.PSObject.Copy(); $ansi.Ansi = $true
        InModuleScope Maester -Parameters @{ plain = $script:stream; ansi = $ansi } {
            param($plain, $ansi)
            Format-MtConsoleText 'x' -Style Failed -Console $plain | Should -Be 'x'
            Format-MtConsoleText 'x' -Style Failed -Console $ansi | Should -Be "$([char]27)[31mx$([char]27)[0m"
        }
    }
}

Describe 'Write-MtCIAnnotation' {
    BeforeAll {
        $script:rows = @(
            [pscustomobject]@{ Id = 'MT.1'; Title = 'Policy, with: comma'; Result = 'Failed'; ReasonDetail = $null }
            [pscustomobject]@{ Id = 'MT.2'; Title = 'Broken'; Result = 'Error'; ReasonDetail = "An error occurred.`n`nThe API returned 403; denied]" }
            [pscustomobject]@{ Id = 'MT.3'; Title = 'Fine'; Result = 'Passed'; ReasonDetail = $null }
        )
    }

    It 'Writes GitHub warnings for Failed and errors for Error rows' {
        $gh = $script:stream.PSObject.Copy(); $gh.CI = 'GitHubActions'
        $lines = InModuleScope Maester -Parameters @{ c = $gh; rows = $script:rows } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines.Count | Should -Be 2
        $lines[0] | Should -Be '::warning title=Maester MT.1::Failed: Policy, with: comma'
        $lines[1] | Should -Match '^::error title=Maester MT\.2::Error: Broken - '
    }

    It 'Escapes Azure Pipelines logging command characters' {
        $ado = $script:stream.PSObject.Copy(); $ado.CI = 'AzureDevOps'
        $lines = InModuleScope Maester -Parameters @{ c = $ado; rows = $script:rows } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines[1] | Should -Match '^##vso\[task\.logissue type=error\]MT\.2: Error: Broken'
        $lines[1].Substring('##vso[task.logissue type=error]'.Length) | Should -Not -Match '[;\]\r\n]'
    }

    It 'Annotates at most -Limit rows and says how many were left out' {
        $gh = $script:stream.PSObject.Copy(); $gh.CI = 'GitHubActions'
        $many = 1..5 | ForEach-Object { [pscustomobject]@{ Id = "MT.$_"; Title = 't'; Result = 'Failed'; ReasonDetail = $null } }
        $lines = InModuleScope Maester -Parameters @{ c = $gh; rows = $many } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Limit 2 -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines.Count | Should -Be 3
        $lines[2] | Should -Match '3 more'
    }

    It 'Writes nothing outside CI' {
        $lines = InModuleScope Maester -Parameters @{ c = $script:stream; rows = $script:rows } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Console $c 6>&1 }
        $lines | Should -BeNullOrEmpty
    }
}

Describe 'Write-MtRunSummary' {
    BeforeAll {
        $script:plain = $script:stream.PSObject.Copy(); $script:plain.Unicode = $false
        $script:results = [pscustomobject]@{
            PassedCount = 2; FailedCount = 2; ErrorCount = 1; InvestigateCount = 0; SkippedCount = 1; NotRunCount = 1; TotalCount = 7; TotalDuration = '00:00:01.5'
            Tests = @(
                [pscustomobject]@{ Id = 'A.1'; Product = 'Exchange Online'; Result = 'Passed'; Severity = 'High' }
                [pscustomobject]@{ Id = 'A.2'; Product = 'Entra ID'; Result = 'Failed'; Severity = 'Medium' }
                [pscustomobject]@{ Id = 'A.3'; Product = 'Entra ID'; Result = 'Failed'; Severity = 'Critical' }
                [pscustomobject]@{ Id = 'A.4'; Product = 'Entra ID'; Result = 'Passed'; Severity = 'Low' }
                [pscustomobject]@{ Id = 'A.5'; Product = 'Entra ID'; Result = 'NotRun'; Severity = 'Low' }
                [pscustomobject]@{ Id = 'A.6'; Product = $null; Result = 'Error'; Severity = 'Low' }
                [pscustomobject]@{ Id = 'A.7'; Result = 'Skipped' }
            )
        }
        $script:summary = @(InModuleScope Maester -Parameters @{ c = $script:plain; r = $script:results } { param($c, $r) Write-MtRunSummary -MaesterResults $r -ReportPath 'out/report.html' -Console $c 6>&1 } | ForEach-Object { "$_" })
    }

    It 'Writes every count, the total and the report path' {
        $text = $script:summary -join "`n"
        $text | Should -Match 'Passed: 2, Failed: 2, Errors: 1, Investigate: 0, Skipped: 1, Not run: 1'
        $text | Should -Match '\(7 tests, 1\.5 s\)'
        $text | Should -Match 'Report out/report\.html'
    }

    It 'Has one row per product, in the order of the product list, with tests that have no product under Other' {
        $rows = @($script:summary | Where-Object { $_ -match '^ (Entra ID|Exchange Online|Other) ' })
        $rows.Count | Should -Be 3
        $rows[0] | Should -Match '^ Entra ID'
        $rows[1] | Should -Match '^ Exchange Online'
        $rows[2] | Should -Match '^ Other'
    }

    It 'Counts each result per product, leaves NotRun out, and names the worst failed severity' {
        $entra = $script:summary | Where-Object { $_ -match '^ Entra ID' }
        ($entra -split '\s+' | Where-Object { $_ })[2..7] -join ' ' | Should -Be '1 2 0 0 0 Critical'
        ($script:summary | Where-Object { $_ -match '^ Other' }) | Should -Match '^ Other\s+0\s+0\s+1\s+0\s+1$'
    }
}

Describe 'Connection info' {
    BeforeAll {
        $script:context = [pscustomobject]@{
            TenantName = 'Contoso'; Account = 'merill@contoso.com'
            Services   = [pscustomobject]@{ Graph = $true; ExchangeOnline = $true; Teams = $false; Azure = $false; ActiveDirectory = $false }
        }
        $script:planRows = @(
            [pscustomobject]@{ Disposition = 'Skipped'; Test = [pscustomobject]@{ Service = @('Teams') } }
            [pscustomobject]@{ Disposition = 'Skipped'; Test = [pscustomobject]@{ Service = @('Teams') } }
            [pscustomobject]@{ Disposition = 'Run'; Test = [pscustomobject]@{ Service = @('Graph') } }
        )
        $script:connections = @(InModuleScope Maester -Parameters @{ t = $script:context; p = $script:planRows } { param($t, $p) Get-MtConnectionInfo -TenantContext $t -Plan $p })
    }

    It 'Lists connected services, and services that are not connected only when tests are skipped for them' {
        $script:connections.Name | Should -Be @('Graph', 'Exchange Online', 'Teams')
        ($script:connections | Where-Object Name -EQ 'Graph').Detail | Should -Be 'Contoso · merill@contoso.com'
        ($script:connections | Where-Object Name -EQ 'Teams').Detail | Should -Be 'not connected · 2 tests will be skipped'
    }

    It 'Lists the connected services first, then the others, each by name with Graph first' {
        $context = [pscustomobject]@{
            TenantName = 'Contoso'; Account = 'a@contoso.com'
            Services   = [pscustomobject]@{ Teams = $true; Azure = $false; Graph = $true; SharePointOnline = $false; ExchangeOnline = $true }
        }
        $plan = 'Azure', 'SharePointOnline' | ForEach-Object { [pscustomobject]@{ Disposition = 'Skipped'; Test = [pscustomobject]@{ Service = @($_) } } }
        $rows = @(InModuleScope Maester -Parameters @{ t = $context; p = $plan } { param($t, $p) Get-MtConnectionInfo -TenantContext $t -Plan $p })
        $rows.Name | Should -Be @('Graph', 'Exchange Online', 'Teams', 'Azure', 'SharePoint Online')
        $rows.Connected | Should -Be @($true, $true, $true, $false, $false)
    }

    It 'Links maester.dev in the banner' {
        $esc = [char]27
        $wide = $script:stream.PSObject.Copy(); $wide.Mode = 'Interactive'; $wide.Width = 120; $wide.Ansi = $true; $wide.ColorDepth = 'TrueColor'
        foreach ($width in 120, 60) {
            $wide.Width = $width
            $banner = InModuleScope Maester -Parameters @{ c = $wide } { param($c) Get-MtBanner -Console $c }
            ($banner.Lines -join "`n") | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev$esc\maester.dev$esc]8;;$esc\"))
        }
        $wide.Ansi = $false; $wide.ColorDepth = 'None'
        $plain = InModuleScope Maester -Parameters @{ c = $wide } { param($c) Get-MtBanner -Console $c }
        ($plain.Lines -join "`n") | Should -Not -Match ([regex]::Escape("$esc"))
    }

    It 'Formats one line per service, and one line for the dashboard with its visible length' {
        $lines = @(InModuleScope Maester -Parameters @{ c = $script:stream; x = $script:connections } { param($c, $x) Format-MtConnectionInfo -Connection $x -Console $c })
        $lines.Count | Should -Be 3
        $lines[2] | Should -Match '○ Teams\s+not connected'
        $one = InModuleScope Maester -Parameters @{ c = $script:stream; x = $script:connections } { param($c, $x) Format-MtConnectionInfo -Connection $x -OneLine -Console $c }
        $one.Text | Should -Be ' Contoso · merill@contoso.com · ● Graph  ● Exchange Online  ○ Teams'
        $one.Length | Should -Be $one.Text.Length
        # The dashboard has the tenant in its own panel: the line then has the services only.
        $services = InModuleScope Maester -Parameters @{ c = $script:stream; x = $script:connections } { param($c, $x) Format-MtConnectionInfo -Connection $x -OneLine -NoTenant -Console $c }
        $services.Text | Should -Be ' ● Graph  ● Exchange Online  ○ Teams'
    }

    It 'Writes a count in a few characters' {
        $cases = [ordered]@{ 0 = '0'; 87 = '87'; 999 = '999'; 1000 = '1K'; 1204 = '1.2K'; 48211 = '48.2K'; 999960 = '1M'; 3400000 = '3.4M'; 1100000000 = '1.1B' }
        foreach ($case in $cases.GetEnumerator()) {
            InModuleScope Maester -Parameters @{ n = $case.Key } { param($n) Format-MtCompactNumber $n } | Should -Be $case.Value
        }
    }

    It 'Counts the objects of the tenant in one batch request, and leaves out a count it cannot read' {
        $counts = InModuleScope Maester {
            Mock Invoke-MgGraphRequest {
                [pscustomobject]@{ responses = @(
                        [pscustomobject]@{ id = 'Groups'; status = 200; body = '310' }
                        [pscustomobject]@{ id = 'Users'; status = 200; body = 1204 }
                        [pscustomobject]@{ id = 'Guests'; status = 200; body = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('87')) }
                        [pscustomobject]@{ id = 'Devices'; status = 403; body = [pscustomobject]@{ error = 'denied' } }
                        [pscustomobject]@{ id = 'Apps'; status = 200; body = 'not a number' }
                    )
                }
            } -ParameterFilter { $Method -eq 'POST' -and $Uri -eq '/v1.0/$batch' -and $Body -match 'ConsistencyLevel' -and $Body -match 'agentIdentity' }
            Get-MtDashboardTenantCount
        }
        @($counts.Keys) | Should -Be @('Users', 'Guests', 'Groups')
        $counts['Users'] | Should -Be 1204
        $counts['Guests'] | Should -Be 87
        $counts['Groups'] | Should -Be 310
    }

    It 'Has no counts when the request fails' {
        $none = InModuleScope Maester {
            Mock Invoke-MgGraphRequest { throw 'offline' }
            Get-MtDashboardTenantCount
        }
        $none.Count | Should -Be 0
    }
}

Describe 'Deferred console output' {
    It 'Keeps lines while the dashboard owns the screen and writes them when it closes' {
        $lines = InModuleScope Maester {
            $writer = [System.IO.StringWriter]::new()
            $renderer = [Maester.Engine.MtConsoleRenderer]::new($writer)
            $renderer.Width = 100; $renderer.Height = 30; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $script:__MtConsoleRenderer = $renderer
            $script:__MtDeferredOutput = $null
            $renderer.Open()
            $during = @(Write-MtConsoleLine 'kept for later' 6>&1)
            $after = @(Stop-MtConsoleOutput 6>&1)
            [pscustomobject]@{ During = $during.Count; After = @($after | ForEach-Object { "$_" }); Renderer = $script:__MtConsoleRenderer }
        }
        $lines.During | Should -Be 0
        $lines.After | Should -Be @('kept for later')
        $lines.Renderer | Should -BeNullOrEmpty
    }
}

Describe 'Show-MtLogo' {
    It 'Writes one plain line outside Interactive' {
        $text = InModuleScope Maester -Parameters @{ c = $script:stream } { param($c) Show-MtLogo -Console $c 6>&1 } | ForEach-Object { "$_" }
        @($text).Count | Should -Be 1
        $text | Should -Match '^Maester v\d'
    }

    It 'Builds the banner with the flame for a wide console and a small one for a narrow console' {
        $wide = $script:stream.PSObject.Copy(); $wide.Mode = 'Interactive'; $wide.Width = 120; $wide.Ansi = $true; $wide.ColorDepth = 'TrueColor'
        $narrow = $wide.PSObject.Copy(); $narrow.Width = 60
        $big = InModuleScope Maester -Parameters @{ c = $wide } { param($c) Get-MtBanner -Console $c }
        $small = InModuleScope Maester -Parameters @{ c = $narrow } { param($c) Get-MtBanner -Console $c }
        $big.Width | Should -Be 88
        $big.Lines.Count | Should -Be 13
        ($big.Lines -join "`n") | Should -Match ([regex]::Escape("$([char]27)[38;2;"))
        $small.Lines.Count | Should -BeLessThan $big.Lines.Count
        $big.Compact | Should -Match '^Maester v\d'
        # The tagline row, for the dashboard, which writes that row itself.
        $big.Tagline.Row | Should -Be 10
        $big.Lines[10] | Should -Match 'maester\.dev'
        $big.Lines[10].StartsWith($big.Tagline.Prefix) | Should -BeTrue
        $big.Tagline.Version | Should -Match '^v\d'
        $small.Tagline.Row | Should -Be -1
    }

    It 'Never makes a banner line wider than the width it reports' {
        $plain = $script:stream.PSObject.Copy(); $plain.Mode = 'Interactive'; $plain.Width = 120
        $banner = InModuleScope Maester -Parameters @{ c = $plain } { param($c) Get-MtBanner -Console $c }
        foreach ($line in $banner.Lines) { $line.Length | Should -BeLessOrEqual $banner.Width }
    }
}

Describe 'Dashboard panels' {
    BeforeAll {
        function New-PanelRenderer {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param()
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 160; $renderer.Height = 44; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer
        }
        $script:wide = $script:stream.PSObject.Copy(); $script:wide.Mode = 'Interactive'; $script:wide.Width = 160
    }

    It 'Uses the panels of Output.DashboardPanels, and warns about a name it does not know' {
        $renderer = New-PanelRenderer
        $config = [pscustomobject]@{ Output = [pscustomobject]@{ DashboardPanels = @('Tips', 'Nonsense') } }
        $warnings = $null
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; cfg = $config } {
            param($r, $c, $cfg)
            Initialize-MtDashboard -Renderer $r -Console $c -RunConfig $cfg -SkipVersionCheck -WarningVariable w -WarningAction SilentlyContinue
            $script:__panelWarnings = $w
        }
        $warnings = InModuleScope Maester { $script:__panelWarnings }
        "$warnings" | Should -Match 'Nonsense'
        $renderer.Start(2)
        $renderer.ItemFinished('Failed')
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match 'Tip'
        $screen | Should -Not -Match 'Failed so far'
        $renderer.Close()
    }

    It 'Shows no panels for an empty Output.DashboardPanels' {
        $renderer = New-PanelRenderer
        $config = [pscustomobject]@{ Output = [pscustomobject]@{ DashboardPanels = @() } }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; cfg = $config } { param($r, $c, $cfg) Initialize-MtDashboard -Renderer $r -Console $c -RunConfig $cfg -SkipVersionCheck }
        $renderer.Start(2)
        $renderer.ItemFinished('Failed')
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Not -Match 'Tip|Failed so far|■'
        $renderer.Close()
    }

    It 'Says so in the Tenant panel when Graph is not connected' {
        $renderer = New-PanelRenderer
        $context = [pscustomobject]@{ TenantName = $null; Services = [pscustomobject]@{ Graph = $false; ExchangeOnline = $true } }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; t = $context } {
            param($r, $c, $t)
            $r.SetPanels([string[]]@('Tenant'))
            $r.Open()
            Set-MtDashboardTenant -Renderer $r -TenantContext $t -Console $c
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match 'Not connected to Microsoft Graph'
        $screen | Should -Not -Match 'Exchange Online'
        $renderer.Close()
    }

    It 'Shows the tenant, its domain, the account and the counts in the Tenant panel, without the services' {
        $renderer = New-PanelRenderer
        $context = [pscustomobject]@{
            TenantName = 'Contoso'; PrimaryDomain = 'contoso.com'; TenantId = '0817c655'; Account = 'merill@contoso.com'; AuthType = 'Delegated'; Cloud = 'Commercial'; TenantType = 'Workforce'
            Services   = [pscustomobject]@{ Graph = $true; Teams = $false }
        }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; t = $context } {
            param($r, $c, $t)
            $r.SetPanels([string[]]@('Tenant'))
            $r.Open()
            Set-MtDashboardTenant -Renderer $r -TenantContext $t -Count ([ordered]@{ Users = 1204; Guests = 87; Devices = 2500000 }) -Console $c
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '│ Contoso +contoso\.com │'
        $screen | Should -Match 'merill@contoso\.com · Delegated'
        $screen | Should -Match '│ +1\.2K +87 +2\.5M │'
        $screen | Should -Match '│ +Users +Guests +Devices │'
        # The tenant ID, the cloud and the tenant type are not shown.
        $screen | Should -Not -Match '0817c655|Commercial|Workforce'
        $screen | Should -Not -Match 'Teams'
        $renderer.Close()
    }
}
