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

    It 'Switches the console to UTF-8 only on Windows, in a terminal that can draw the dashboard' {
        InModuleScope Maester {
            $earlier = [System.Console]::OutputEncoding
            $wt = $env:WT_SESSION; $program = $env:TERM_PROGRAM
            try {
                # Not a terminal that is known to draw it: nothing changes.
                $env:WT_SESSION = $null; $env:TERM_PROGRAM = 'Apple_Terminal'
                Enable-MtConsoleUtf8 | Should -BeFalse
                # Windows Terminal: only Windows needs the switch, and only when the console is not UTF-8 already.
                $env:WT_SESSION = 'test'
                $needed = $IsWindows -and -not [System.Console]::IsOutputRedirected -and $earlier.CodePage -ne 65001
                Enable-MtConsoleUtf8 | Should -Be $needed
                if ($needed) { [System.Console]::OutputEncoding.CodePage | Should -Be 65001 }
                Restore-MtConsoleEncoding
                [System.Console]::OutputEncoding.CodePage | Should -Be $earlier.CodePage
                # Nothing to restore: no error.
                { Restore-MtConsoleEncoding } | Should -Not -Throw
            } finally {
                $env:WT_SESSION = $wt; $env:TERM_PROGRAM = $program
                [System.Console]::OutputEncoding = $earlier
            }
        }
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
        # Error rows come first, whatever their place in the report.
        $lines[0] | Should -Match '^::error title=Maester MT\.2::Error: Broken - '
        $lines[1] | Should -Be '::warning title=Maester MT.1::Failed: Policy, with: comma'
    }

    It 'Escapes Azure Pipelines logging command characters' {
        $ado = $script:stream.PSObject.Copy(); $ado.CI = 'AzureDevOps'
        $lines = InModuleScope Maester -Parameters @{ c = $ado; rows = $script:rows } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines[0] | Should -Match '^##vso\[task\.logissue type=error\]MT\.2: Error: Broken'
        $lines[0].Substring('##vso[task.logissue type=error]'.Length) | Should -Not -Match '[;\]\r\n]'
    }

    It 'Annotates at most -Limit rows and says how many were left out' {
        $gh = $script:stream.PSObject.Copy(); $gh.CI = 'GitHubActions'
        $many = 1..5 | ForEach-Object { [pscustomobject]@{ Id = "MT.$_"; Title = 't'; Result = 'Failed'; ReasonDetail = $null } }
        $lines = InModuleScope Maester -Parameters @{ c = $gh; rows = $many } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Limit 2 -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines.Count | Should -Be 3
        $lines[2] | Should -Match '3 more'
    }

    It 'Annotates Error rows before Failed rows when the limit cuts the list' {
        $gh = $script:stream.PSObject.Copy(); $gh.CI = 'GitHubActions'
        $many = @(1..5 | ForEach-Object { [pscustomobject]@{ Id = "MT.$_"; Title = 't'; Result = 'Failed'; ReasonDetail = $null } }) +
            @([pscustomobject]@{ Id = 'MT.9'; Title = 'broken'; Result = 'Error'; ReasonDetail = $null })
        $lines = InModuleScope Maester -Parameters @{ c = $gh; rows = $many } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Limit 2 -Console $c 6>&1 } | ForEach-Object { "$_" }
        $lines[0] | Should -Match '^::error title=Maester MT\.9::'
    }

    It 'Writes nothing outside CI' {
        $lines = InModuleScope Maester -Parameters @{ c = $script:stream; rows = $script:rows } { param($c, $rows) Write-MtCIAnnotation -Tests $rows -Console $c 6>&1 }
        $lines | Should -BeNullOrEmpty
    }
}

Describe 'Console text from tests' {
    It 'Keeps a title or reason on one line and breaks up CI commands' {
        $ado = $script:stream.PSObject.Copy(); $ado.CI = 'AzureDevOps'
        $text = "Evil`n::error title=x::y ##vso[task.setvariable variable=X]v`r##[error]z$([char]27)[2J"
        $safe = InModuleScope Maester -Parameters @{ t = $text; c = $ado } { param($t, $c) ConvertTo-MtConsoleSafeText $t -Console $c }
        $safe | Should -Not -Match '[\p{Cc}]'
        $safe | Should -Not -Match '##vso\[|##\['
        $safe | Should -Match '^Evil ::error'
        # At the start of a line GitHub Actions would read '::' as a command.
        InModuleScope Maester -Parameters @{ c = $ado } { param($c) ConvertTo-MtConsoleSafeText '::warning::x' -Console $c } | Should -Be ': :warning::x'
        # Outside CI only the control characters go.
        InModuleScope Maester -Parameters @{ c = $script:stream } { param($c) ConvertTo-MtConsoleSafeText "a`tb ##vso[x]" -Console $c } | Should -Be 'a b ##vso[x]'
    }

    It 'Takes the first line of a reason whatever the line break' {
        InModuleScope Maester { Get-MtFirstLine "first`rsecond" } | Should -Be 'first'
        InModuleScope Maester { Get-MtFirstLine "first`r`nsecond" } | Should -Be 'first'
    }
}

Describe 'Run summary with a severity outside the known five' {
    It 'Shows the severity as it is instead of failing' {
        $results = [pscustomobject]@{
            PassedCount = 0; FailedCount = 1; ErrorCount = 0; InvestigateCount = 0; SkippedCount = 0; NotRunCount = 0; TotalCount = 1; TotalDuration = '00:00:01'
            Tests = @([pscustomobject]@{ Id = 'A.1'; Product = 'Entra ID'; Result = 'Failed'; Severity = 'Informational' })
        }
        $lines = InModuleScope Maester -Parameters @{ r = $results; c = $script:stream } { param($r, $c) & { $ErrorActionPreference = 'Stop'; Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } } | ForEach-Object { "$_" }
        ($lines -join "`n") | Should -Match 'Informational'
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

    It 'Writes the warnings and errors that were collected while the dashboard owned the screen, each once' {
        $out = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 100; $renderer.Height = 30; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $script:__MtConsoleRenderer = $renderer
            $script:__MtDeferredOutput = $null
            $renderer.Open()
            $warning = [System.Management.Automation.WarningRecord]::new('hidden warning')
            $failure = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('hidden error'), 'Hidden', 'NotSpecified', $null)
            # The same record twice: a helper and its caller both collect it.
            $replayedErrors = $null
            $replayed = @(Stop-MtConsoleOutput -Message @($warning, $warning, $failure) -ErrorVariable replayedErrors -ErrorAction SilentlyContinue 3>&1)
            [pscustomobject]@{ Warnings = @($replayed | ForEach-Object { "$_" }); Errors = @($replayedErrors | ForEach-Object { $_.Exception.Message }) }
        }
        $out.Warnings | Should -Be @('hidden warning')
        $out.Errors | Should -Be @('hidden error')
    }

    It 'Does not repeat collected messages when no full-screen dashboard hid them' {
        $out = InModuleScope Maester {
            $script:__MtConsoleRenderer = $null
            $script:__MtDeferredOutput = $null
            @(Stop-MtConsoleOutput -Message @([System.Management.Automation.WarningRecord]::new('already shown')) 3>&1)
        }
        $out | Should -BeNullOrEmpty
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
        # The wordmark that the dashboard shows at the top while tests run: the lettering of the banner in
        # the six rows of the Pace graph, and the version in the row of its caption. No flame.
        $band = $big.Band
        $band.Lines.Count | Should -Be 7
        $strip = { param($line) $line -replace "$([char]27)\[[0-9;]*m" }
        (& $strip $band.Lines[0]) | Should -Be ' ███╗   ███╗ █████╗ ███████╗███████╗████████╗███████╗██████╗ '
        (& $strip $band.Lines[5]) | Should -Be ' ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
        $band.TaglineRow | Should -Be 6
        (& $strip $band.Lines[6]) | Should -Match '^ v\d'
        $band.Width | Should -Be 61
        ($band.Lines -join '') | Should -Not -Match '[▟▙▗▖▜▛]'
        foreach ($line in $band.Lines) { (& $strip $line).Length | Should -BeLessOrEqual $band.Width }
        ($band.Lines -join '') | Should -Not -Match '[▟▙▗▖]'
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

    It 'Puts the links of the project in the status bar' {
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } { param($r, $c) Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck }
        $screen = $renderer.GetPlainScreen(160, 44)
        # Four at the left, four at the right edge, and the bar spans the window.
        $screen[-1] | Should -Match '^ maester\.dev  Docs │ Contributors │ Our Manifesto  +(⌘|Ctrl)-click to open  +Star on GitHub │ Discord │ Issues │ ♥ Sponsor $'
        $screen[-1].Length | Should -Be 159
        $renderer.Close()
    }

    It 'Shows a contributor from the list that ships with the module' {
        $file = Join-Path $PSScriptRoot '../../assets/ConsoleContributors.json'
        $people = @(Get-Content -LiteralPath $file -Raw | ConvertFrom-Json)
        $people.Count | Should -BeGreaterThan 10
        foreach ($person in $people) {
            $person.Name | Should -Not -BeNullOrEmpty
            $person.GitHub | Should -Match '^[A-Za-z0-9-]+$'
        }
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } { param($r, $c) Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck }
        # The list is read on a background thread. Allow up to 20 s: the first JSON read on a cold thread
        # has taken longer than 2 s on a busy Windows CI runner. The loop ends as soon as the panel is drawn.
        $shown = $false
        foreach ($try in 1..400) {
            if (($renderer.GetPlainScreen(160, 44) -join "`n") -match '╭─ Featured contributor ') { $shown = $true; break }
            Start-Sleep -Milliseconds 50
        }
        $shown | Should -BeTrue
        # It is the last panel of the column, under the tip.
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen.IndexOf('╭─ Featured contributor ') | Should -BeGreaterThan $screen.IndexOf('╭─ Tip ')
        $renderer.Close()
    }

    It 'Writes the contributor list from the data of the website, without the people who are pinned last' {
        $source = Join-Path $TestDrive 'contributors.json'
        $destination = Join-Path $TestDrive 'out/ConsoleContributors.json'
        @{ profiles = @(
                @{ id = 'ada-l'; github = 'ada-l'; name = 'Ada Lovelace'; pinLast = $false; firstContribution = '2025-03-01'; testsAuthored = @('A.1', 'A.2'); testsContributed = @('B.1') }
                @{ id = 'pinned'; github = 'pinned'; name = 'Pinned Last'; pinLast = $true; firstContribution = '2024-01-01'; testsAuthored = @(); testsContributed = @() }
                @{ id = 'newp'; github = 'newp'; name = ''; pinLast = $false; firstContribution = ''; testsAuthored = @(); testsContributed = @() }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $source
        & (Join-Path $PSScriptRoot '../../../build/Update-ConsoleContributors.ps1') -Source $source -Destination $destination -InformationAction SilentlyContinue
        $people = @(Get-Content -LiteralPath $destination -Raw | ConvertFrom-Json)
        $people.GitHub | Should -Be @('ada-l', 'newp')
        $people[0].Name | Should -Be 'Ada Lovelace'
        $people[0].Tests | Should -Be 2
        $people[0].Improvements | Should -Be 1
        $people[0].Since | Should -Be 2025
        $people[1].Name | Should -Be 'newp'
        $people[1].Since | Should -Be 0
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

    It 'Shows the tenant, its domain and the account in the Tenant panel, without the services' {
        $renderer = New-PanelRenderer
        $context = [pscustomobject]@{
            TenantName = 'Contoso'; PrimaryDomain = 'contoso.com'; TenantId = '0817c655'; Account = 'merill@contoso.com'; AuthType = 'Delegated'; Cloud = 'Commercial'; TenantType = 'Workforce'
            Services   = [pscustomobject]@{ Graph = $true; Teams = $false }
        }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; t = $context } {
            param($r, $c, $t)
            $r.SetPanels([string[]]@('Tenant'))
            $r.Open()
            Mock Invoke-MgGraphRequest { throw 'The Tenant panel must not request anything' }
            Mock Invoke-MtGraphRequest { throw 'The Tenant panel must not request anything' }
            Set-MtDashboardTenant -Renderer $r -TenantContext $t -Console $c
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '│ Contoso +contoso\.com │'
        $screen | Should -Match 'merill@contoso\.com · Delegated'
        # Two lines: the tenant ID, the cloud, the tenant type and counts of its objects are not shown.
        @($renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '│$' }).Count | Should -Be 2
        $screen | Should -Not -Match '0817c655|Commercial|Workforce'
        $screen | Should -Not -Match 'Teams'
        $renderer.Close()
    }
}
