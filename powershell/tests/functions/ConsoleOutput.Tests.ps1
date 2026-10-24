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
            Tests = @([pscustomobject]@{ Id = 'A.1'; Product = 'entra'; Result = 'Failed'; Severity = 'Informational' })
        }
        $lines = InModuleScope Maester -Parameters @{ r = $results; c = $script:stream } { param($r, $c) $ErrorActionPreference = 'Stop'; Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" }
        ($lines -join "`n") | Should -Match 'Informational'
    }
}

Describe 'Write-MtRunSummary' {
    BeforeAll {
        $script:plain = $script:stream.PSObject.Copy(); $script:plain.Unicode = $false
        $script:results = [pscustomobject]@{
            PassedCount = 2; FailedCount = 2; ErrorCount = 1; InvestigateCount = 0; SkippedCount = 1; NotRunCount = 1; TotalCount = 7; TotalDuration = '00:00:01.5'
            Tests = @(
                [pscustomobject]@{ Id = 'A.1'; Product = 'exchange'; Result = 'Passed'; Severity = 'High' }
                [pscustomobject]@{ Id = 'A.2'; Product = 'entra'; Result = 'Failed'; Severity = 'Medium' }
                [pscustomobject]@{ Id = 'A.3'; Product = 'entra'; Result = 'Failed'; Severity = 'Critical' }
                [pscustomobject]@{ Id = 'A.4'; Product = 'entra'; Result = 'Passed'; Severity = 'Low' }
                [pscustomobject]@{ Id = 'A.5'; Product = 'entra'; Result = 'NotRun'; Severity = 'Low' }
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

    It 'Has one row per product, named by the taxonomy registry, with tests that have no product under Other' {
        $rows = @($script:summary | Where-Object { $_ -match '^ (Entra ID|Exchange Online|Other) ' })
        $rows.Count | Should -Be 3
        $rows[0] | Should -Match '^ Entra ID'
        $rows[1] | Should -Match '^ Exchange Online'
        $rows[2] | Should -Match '^ Other'
    }

    It 'Puts the product with the most passed tests first, and the products with only skipped tests last, by name' {
        $tests = @(
            # Teams and Azure: nothing but skipped tests. Intune: no test passed, but they ran.
            'teams', 'teams', 'azure' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Skipped' } }
            'intune', 'intune' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Failed'; Severity = 'High' } }
            'exchange', 'exchange', 'exchange' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Passed' } }
            'entra' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Passed' } }
            'entra', 'entra', 'entra', 'entra' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Failed'; Severity = 'Low' } }
            'defender' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Passed' } }
            'defender' | ForEach-Object { [pscustomobject]@{ Product = $_; Result = 'Skipped' } }
        )
        $results = [pscustomobject]@{
            PassedCount = 5; FailedCount = 6; ErrorCount = 0; InvestigateCount = 0; SkippedCount = 4; NotRunCount = 0; TotalCount = 15; TotalDuration = '00:00:01'
            Tests = $tests
        }
        $lines = @(InModuleScope Maester -Parameters @{ c = $script:plain; r = $results } { param($c, $r) Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" })
        $names = @($lines | ForEach-Object { if ($_ -match '^ (Azure|Defender|Entra ID|Exchange Online|Intune|Teams) ') { $Matches[1] } })
        # Exchange 3 passed; Defender and Entra ID 1 each, by name; Intune none; then the skipped ones by name.
        $names | Should -Be 'Exchange Online', 'Defender', 'Entra ID', 'Intune', 'Azure', 'Teams'
    }

    It 'Lists the tests of Maester Packs by pack, after the products and apart from them' {
        $pack = [pscustomobject]@{ Id = 'maester.zero-trust-assessment'; Name = 'Microsoft Zero Trust Assessment' }
        $results = [pscustomobject]@{
            PassedCount = 2; FailedCount = 1; ErrorCount = 0; InvestigateCount = 0; SkippedCount = 0; NotRunCount = 0; TotalCount = 3; TotalDuration = '00:00:01'
            Tests = @(
                [pscustomobject]@{ Id = 'A.1'; Product = 'entra'; Result = 'Passed'; Severity = 'High'; Package = $null }
                [pscustomobject]@{ Id = 'ZTA.1'; Product = 'entra'; Result = 'Passed'; Severity = 'High'; Package = $pack }
                [pscustomobject]@{ Id = 'ZTA.2'; Product = 'entra'; Result = 'Failed'; Severity = 'High'; Package = $pack }
            )
        }
        $lines = @(InModuleScope Maester -Parameters @{ c = $script:plain; r = $results } { param($c, $r) Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" })
        $product = [array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -match '^ Product ' })
        $packs = [array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -match '^ Maester Pack ' })
        $product | Should -BeGreaterOrEqual 0
        $packs | Should -BeGreaterThan $product
        $lines[$product + 1] | Should -Match '^ Entra ID +1 +0 '
        $lines[$packs + 1] | Should -Match '^ Microsoft Zero Trust Assessment +1 +1 +0 +0 +0 +High'
        @($lines | Where-Object { $_ -match '^ Entra ID ' }).Count | Should -Be 1
    }

    It 'Takes a product name from the result when it has one, and shows a product it cannot name as written' {
        $results = [pscustomobject]@{
            PassedCount = 2; FailedCount = 0; ErrorCount = 0; InvestigateCount = 0; SkippedCount = 0; NotRunCount = 0; TotalCount = 2; TotalDuration = '00:00:01'
            Taxonomy = [pscustomobject]@{ Products = @([pscustomobject]@{ Key = 'contoso-crm'; Name = 'Contoso CRM' }) }
            Tests = @(
                [pscustomobject]@{ Id = 'A.1'; Product = 'contoso-crm'; Result = 'Passed'; Severity = 'High' }
                [pscustomobject]@{ Id = 'A.2'; Product = 'My product'; Result = 'Passed'; Severity = 'High' }
            )
        }
        $lines = @(InModuleScope Maester -Parameters @{ c = $script:plain; r = $results } { param($c, $r) Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" })
        @($lines | Where-Object { $_ -match '^ Contoso CRM ' }).Count | Should -Be 1
        @($lines | Where-Object { $_ -match '^ My product ' }).Count | Should -Be 1
    }

    It 'Counts each result per product, leaves NotRun out, and names the worst failed severity' {
        $entra = $script:summary | Where-Object { $_ -match '^ Entra ID' }
        ($entra -split '\s+' | Where-Object { $_ })[2..7] -join ' ' | Should -Be '1 2 0 0 0 Critical'
        ($script:summary | Where-Object { $_ -match '^ Other' }) | Should -Match '^ Other\s+0\s+0\s+1\s+0\s+1$'
    }

    It 'Shows how the game of the dashboard went in a frame after the run when it was played, and nothing when it was not' {
        $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
        $renderer.Width = 120; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
        # Only the run is on the course of this game, and it is on screen at once.
        $renderer.GameSeed = 7; $renderer.GameCourseOnly = $true; $renderer.GameSkipOpening = $true
        $renderer.SetTenant('Contoso', 'contoso.example', 'admin@contoso.example')
        $renderer.GameBestPath = Join-Path $TestDrive 'best/run-best.txt'
        $renderer.Open()
        $renderer.Start(10)
        $write = {
            param($Renderer, $Console)
            @(InModuleScope Maester -Parameters @{ c = $Console; res = $script:results; r = $Renderer } { param($c, $res, $r) Write-MtRunSummary -MaesterResults $res -ReportPath 'out/report.html' -Console $c -Renderer $r 6>&1 } | ForEach-Object { "$_" })
        }
        ((& $write $renderer $script:plain) -join "`n") | Should -Not -Match 'MAESTER RUN'
        ((& $write $null $script:plain) -join "`n") | Should -Be ($script:summary -join "`n")
        Test-Path -LiteralPath $renderer.GameBestPath | Should -BeFalse
        # A game: three passed tests collected, of the ten of the run.
        'd', 'e', 'a', 'd' | ForEach-Object { $renderer.SendKey([ConsoleKey]0, [char]$_) }
        foreach ($n in 1..3) {
            $renderer.ItemStarting("P.$n", 'A passed test', $null)
            $renderer.ItemFinished("P.$n", 'Passed', 'Low')
            $renderer.AdvanceGame(8)
        }
        $renderer.Close()
        # The frame is the last thing of the summary, after the renderer gave the screen back.
        $lines = & $write $renderer $script:plain
        $today = [datetime]::Now.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
        $frame = $lines[($script:summary.Count - 1)..($lines.Count - 2)]
        # The name and the site, the score, what made it, and the best score: 44 columns between the sides.
        $row = { param($text) ' |  ' + $text.PadRight(44) + '  |' }
        $frame | Should -Be @(
            ' +------------------------------------------------+'
            (& $row ('MAESTER RUN' + (' ' * 22) + 'maester.dev'))
            (& $row '')
            (& $row 'SCORE  3,000  of 10,000')
            (& $row '3 coins, 0 stomps, best streak 3, 0 hits')
            (& $row "A new best score for you, on $today")
            ' +------------------------------------------------+'
        )
        $lines[-1] | Should -BeNullOrEmpty
        # The best score was written, and a second summary of the same run does not make it new again.
        (Get-Content -LiteralPath $renderer.GameBestPath -Raw) | Should -Be "3000 $today`n"
        # Nothing of the tenant is in it.
        ($frame -join "`n") | Should -Not -Match 'ontoso|admin|example'

        # With Unicode: a frame of lines, the name in two rows of half blocks that are as wide as the
        # frame, the site at the right of the score, and dots between the numbers. Nine lines at the most.
        $unicode = & $write $renderer $script:stream
        $unicode[$script:summary.Count - 1] | Should -Match '^ ╭─{49}╮$'
        $unicode[$script:summary.Count] | Should -Be ' │  █▀▄▀█ ▄▀█ █▀▀ █▀ ▀█▀ █▀▀ █▀█   █▀█ █ █ █▄ █    │'
        $unicode[$script:summary.Count + 1] | Should -Be ' │  █ ▀ █ █▀█ ██▄ ▄█  █  ██▄ █▀▄   █▀▄ █▄█ █ ▀█    │'
        $unicode[$script:summary.Count + 3] | Should -Be ' │  SCORE  3,000  of 10,000           maester.dev  │'
        $unicode[$script:summary.Count + 4] | Should -Be ' │  3 coins · 0 stomps · best streak 3 · 0 hits    │'
        $unicode[-2] | Should -Match '^ ╰─{49}╯$'
        ($unicode.Count - $script:summary.Count) | Should -BeLessOrEqual 9
        # With colour the name has the colours of the wordmark, from Maester red to amber: of the 216
        # colours of the cube on a terminal without 24 bits, and of all of them on one that has them.
        $colour = $script:stream.PSObject.Copy(); $colour.Ansi = $true
        $text = (& $write $renderer $colour) -join "`n"
        $text | Should -Match ([regex]::Escape("$([char]27)[0;1;38;5;167m█"))
        $text | Should -Match ([regex]::Escape("$([char]27)[0;1;38;5;221m█"))
        $text | Should -Not -Match 'MAESTER RUN'
        $text | Should -Match ([regex]::Escape("SCORE  $([char]27)[1;38;5;208m3,000$([char]27)[0m"))
        $renderer.TrueColor = $true
        $text = (& $write $renderer $colour) -join "`n"
        $text | Should -Match ([regex]::Escape("$([char]27)[0;1;38;2;229;36;59m█"))
        $text | Should -Match ([regex]::Escape("$([char]27)[0;1;38;2;255;181;71m█"))
        $renderer.TrueColor = $false

        # A later run with a lower score says what the best one was.
        Set-Content -LiteralPath $renderer.GameBestPath -Value '8150 2026-01-31' -NoNewline
        $second = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
        $second.Width = 120; $second.Height = 40; $second.RefreshIntervalMs = 0; $second.FullScreen = $true; $second.GameSkipOpening = $true
        $second.GameBestPath = $renderer.GameBestPath
        $second.Open()
        $second.Start(10)
        'd', 'e', 'a', 'd' | ForEach-Object { $second.SendKey([ConsoleKey]0, [char]$_) }
        $second.Close()
        $lines = & $write $second $script:plain
        $lines[-5] | Should -Be (& $row 'SCORE  0  of 10,000')
        $lines[-4] | Should -Be (& $row '0 coins, 0 stomps, best streak 0, 0 hits')
        $lines[-3] | Should -Be (& $row 'Your best so far: 8,150, on 2026-01-31')
        (Get-Content -LiteralPath $renderer.GameBestPath -Raw) | Should -Be '8150 2026-01-31'
    }

    It 'Says on the debug stream how the frames of the game went, for a run with -Debug, and nothing of it when the game was not played' {
        $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
        $renderer.Width = 120; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
        $renderer.GameSeed = 7; $renderer.GameCourseOnly = $true; $renderer.GameSkipOpening = $true
        $renderer.Open()
        $renderer.Start(10)
        $write = {
            param($Renderer)
            $all = @(InModuleScope Maester -Parameters @{ c = $script:plain; res = $script:results; r = $Renderer } { param($c, $res, $r) Write-MtRunSummary -MaesterResults $res -ReportPath 'out/report.html' -Console $c -Renderer $r -Debug 5>&1 6>&1 })
            [pscustomobject]@{
                Debug = @($all | Where-Object { $_ -is [System.Management.Automation.DebugRecord] } | ForEach-Object { $_.Message })
                Lines = @($all | Where-Object { $_ -isnot [System.Management.Automation.DebugRecord] } | ForEach-Object { "$_" })
            }
        }
        # Frames of the dashboard are not counted, and a run without the game says nothing.
        1..3 | ForEach-Object { $renderer.Tick() }
        $written = & $write $renderer
        @($written.Debug -match 'frames').Count | Should -Be 0
        ($written.Lines -join "`n") | Should -Be ($script:summary -join "`n")
        # A game, and four frames of it, with half of the run done at the last of them.
        'd', 'e', 'a', 'd' | ForEach-Object { $renderer.SendKey([ConsoleKey]0, [char]$_) }
        foreach ($n in 1..5) {
            $renderer.ItemStarting("P.$n", 'A passed test', $null)
            $renderer.ItemFinished("P.$n", 'Passed', 'Low')
            $renderer.AdvanceGame(2)
        }
        1..4 | ForEach-Object { $renderer.Tick() }
        $renderer.Close()
        $written = & $write $renderer
        # One line, after the frame of the game: how many frames, the longest time between two and when
        # that was, how late a tick was and what it waited for, and how much was written.
        $said = @($written.Debug -match 'frames')
        $said.Count | Should -Be 1
        $said[0] | Should -Match '^Console frames: 4; longest gap \d+ ms at \d+% of the run; 0 over 150 ms; a tick was \d+ ms late at most and waited \d+ ms at most; a frame took \d+ ms to work out and \d+ ms to write at most; [\d,]+ characters\.$'
        # Nothing of it is in what the summary writes for everyone, and nothing of the tenant is in it.
        ($written.Lines -join "`n") | Should -Not -Match 'Console frames'
        ($written.Lines -join "`n") | Should -Match 'MAESTER RUN'
        # Without -Debug it is not written at all.
        $quiet = @(InModuleScope Maester -Parameters @{ c = $script:plain; res = $script:results; r = $renderer } { param($c, $res, $r) Write-MtRunSummary -MaesterResults $res -ReportPath 'out/report.html' -Console $c -Renderer $r 5>&1 6>$null })
        $quiet.Count | Should -Be 0
    }

}

Describe 'Write-MtSponsorMessage' {
    It 'Says that Maester runs on sponsorships, with a link to the sponsor page' {
        $lines = @(InModuleScope Maester -Parameters @{ c = $script:stream } { param($c) Write-MtSponsorMessage -Console $c 6>&1 } | ForEach-Object { "$_" })
        $text = $lines -join "`n"
        $text | Should -Match '♥  Maester runs on sponsorships'
        $text | Should -Match 'rely on sponsors to keep it going'
        $text | Should -Match 'https://maester\.dev/sponsor'
    }

    It 'Writes each line once, with no animation and no colour, outside an interactive console' {
        $plain = $script:stream.PSObject.Copy(); $plain.Mode = 'Plain'; $plain.Unicode = $false
        $lines = @(InModuleScope Maester -Parameters @{ c = $plain } { param($c) Write-MtSponsorMessage -Console $c 6>&1 } | ForEach-Object { "$_" })
        @($lines | Where-Object { $_ -match 'runs on sponsorships' }).Count | Should -Be 1
        $lines[0] | Should -Be ' <3  Maester runs on sponsorships'
        ($lines -join '') | Should -Not -Match "$([char]27)"
    }

    It 'Is a hyperlink where the console shows them' {
        $linked = $script:stream.PSObject.Copy(); $linked.Hyperlink = $true
        $text = @(InModuleScope Maester -Parameters @{ c = $linked } { param($c) Write-MtSponsorMessage -Console $c 6>&1 } | ForEach-Object { "$_" }) -join "`n"
        $esc = [char]27
        $text | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/sponsor$esc\https://maester.dev/sponsor$esc]8;;$esc\"))
    }
}

Describe 'Read-MtTenantContext' {
    It 'Says what it found after each step: the account, the organization, then each service' {
        $steps = [System.Collections.Generic.List[string]]::new()
        $context = InModuleScope Maester -Parameters @{ steps = $steps } {
            Mock Test-MtConnection { $Service -in 'Graph', 'Azure' }
            Mock Get-MgContext { [pscustomobject]@{ TenantId = 'tid'; Account = 'merill@contoso.com'; AuthType = 'Delegated'; Environment = 'Global'; Scopes = @() } }
            Mock Invoke-MtGraphRequest {
                if ($RelativeUri -eq 'organization') { [pscustomobject]@{ displayName = 'Contoso'; tenantType = 'AAD'; verifiedDomains = @([pscustomobject]@{ name = 'contoso.com'; isDefault = $true }) } }
            }
            Read-MtTenantContext -Service 'Graph', 'Azure', 'Teams' -OnStep {
                param($name, $data)
                $steps.Add("$name $(($data.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')")
            }
        }
        $steps | Should -Be @(
            'Account Account=merill@contoso.com AuthType=Delegated Graph=True TenantId=tid'
            'Organization PrimaryDomain=contoso.com TenantName=Contoso'
            'Service Connected=True Name=Graph'
            'Service Connected=True Name=Azure'
            'Service Connected=False Name=Teams'
        )
        # The context is what Get-MtTenantContext returns.
        $context.TenantName | Should -Be 'Contoso'
        $context.PrimaryDomain | Should -Be 'contoso.com'
        $context.TenantType | Should -Be 'Workforce'
        $context.Services.Azure | Should -BeTrue
        $context.Services.Teams | Should -BeFalse
    }

    It 'Returns the context when a step throws, and without a step' {
        InModuleScope Maester {
            Mock Test-MtConnection { $false }
            (Read-MtTenantContext -Service 'Graph' -OnStep { throw 'no display' }).Services.Graph | Should -BeFalse
            (Get-MtTenantContext -Service 'Graph').Services.Graph | Should -BeFalse
        }
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

    It 'Collects for the dashboard only the warnings and errors that would have been shown' {
        $out = InModuleScope Maester {
            function Write-TestMessage { [CmdletBinding()] param() Write-Warning 'from a helper'; Write-Error 'failed in a helper' }
            function Invoke-TestHelper { [CmdletBinding()] param() Write-TestMessage }
            $mtDashboardWarnings = [System.Collections.ArrayList]::new()
            $mtDashboardErrors = [System.Collections.ArrayList]::new()
            $PSDefaultParameterValues = Get-MtDashboardMessageDefault -Default $PSDefaultParameterValues
            & {
                $WarningPreference = 'Continue'; $ErrorActionPreference = 'Continue'
                # Shown: two levels down, and here.
                Invoke-TestHelper
                Write-Warning 'written here'
                # Kept quiet by the caller, by a preference, and by the command itself: the check for a next
                # page of every Graph request, and the JSON export of the results.
                Invoke-TestHelper -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                & { $WarningPreference = 'SilentlyContinue'; $ErrorActionPreference = 'SilentlyContinue'; Write-TestMessage }
                $null = Get-ObjectProperty ([pscustomobject]@{ value = 1 }) '@odata.nextLink'
                $null = @{ a = @{ b = @{ c = 1 } } } | ConvertTo-Json -Depth 1 -WarningAction SilentlyContinue
            } 2>$null 3>$null
            [pscustomobject]@{ Warnings = @($mtDashboardWarnings | ForEach-Object { $_.Message }); Errors = @($mtDashboardErrors | ForEach-Object { "$_" }) }
        }
        $out.Warnings | Should -Be @('from a helper', 'written here')
        $out.Errors | Should -Be @('failed in a helper')
    }

    It 'Keeps the defaults that were set and adds them for Write-Warning and Write-Error only' {
        $defaults = InModuleScope Maester { Get-MtDashboardMessageDefault -Default @{ 'Get-Thing:Name' = 'kept' } }
        $defaults['Get-Thing:Name'] | Should -Be 'kept'
        @($defaults.Keys | Sort-Object) | Should -Be @('Get-Thing:Name', 'Write-Error:ErrorVariable', 'Write-Warning:WarningVariable')
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

    It 'Knows the insight panels, and Fix first, by name' {
        $renderer = New-PanelRenderer
        $config = [pscustomobject]@{ Output = [pscustomobject]@{ DashboardPanels = @('FixFirst', 'WeakestAreas', 'AttackTactics', 'FailedTests', 'NistFamilies', 'PassRate', 'EveryTest') } }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; cfg = $config } {
            param($r, $c, $cfg)
            Initialize-MtDashboard -Renderer $r -Console $c -RunConfig $cfg -SkipVersionCheck -WarningVariable w -WarningAction SilentlyContinue
            $script:__panelWarnings = $w
        }
        InModuleScope Maester { $script:__panelWarnings } | Should -BeNullOrEmpty
        $renderer.Close()
    }

    It 'Hands the attributes of the tests to the dashboard, for a run of 25 tests or more' {
        $newItems = {
            param([int] $count)
            [Maester.Engine.MtWorkItem[]]@(1..$count | ForEach-Object {
                    $test = [pscustomobject]@{
                        Area = 'privileged-access'; Severity = 'High'; UserImpact = 'Low'; ImplementationCost = 'Low'
                        Mitre = @('T1078.004'); Control = @('nist-800-53-r5:AC-6(5)', 'cisa-scuba:MS.AAD.7.1')
                    }
                    $item = [Maester.Engine.MtWorkItem]::new(); $item.Id = "X.$_"; $item.Tag = @{ PlanRow = [pscustomobject]@{ Test = $test }; Instance = $null }
                    $item
                })
        }
        $run = {
            param([int] $count)
            $renderer = New-PanelRenderer
            $renderer.Height = 60
            InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide; items = (& $newItems $count) } {
                param($r, $c, $items)
                Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck
                Set-MtDashboardTestInfo -Renderer $r -WorkItem $items
            }
            $renderer.Start($count)
            1..$count | ForEach-Object { $renderer.ItemStarting("X.$_", "Test $_", $null); $renderer.ItemFinished("X.$_", $(if ($_ % 2) { 'Failed' } else { 'Passed' }), 'High', 1) }
            $screen = $renderer.GetPlainScreen(160, 60) -join "`n"
            $renderer.Close()
            $screen
        }
        $screen = & $run 26
        # The names come from the taxonomy registry, the pinned ATT&CK release and the NIST control list.
        $screen | Should -Match 'Weakest areas'
        $screen | Should -Match '│ Privileged access +\S+ +50% ✗ 13 │'
        $screen | Should -Match 'ATT&CK tactics'
        $screen | Should -Match '│ AC Access Control +\S+ +50% ✗ 13 │'
        $screen | Should -Match 'Fix first ─+ 13 quick wins ─'
        # A run of a few tests has no insight panels.
        & $run 24 | Should -Not -Match 'Weakest areas|ATT&CK tactics|NIST 800-53|Fix first|Pass rate so far'
    }

    It 'Shows the tenant and the services while the tenant context is read, and fills in each answer' {
        $renderer = New-PanelRenderer
        $right = { @($renderer.GetPlainScreen(160, 44) | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' }) -join "`n" }
        $step = InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            # Teams is loaded in this session, so whether it is connected needs asking; Exchange is not
            # loaded, so it is not connected, and that is known at once. No Graph session yet.
            Mock Test-MtModuleImported { $Name -eq 'MicrosoftTeams' }
            Mock Get-MgContext { $null }
            Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck
            Start-MtDashboardTenant -Renderer $r -Console $c -Service 'Graph', 'Teams', 'ExchangeOnline', 'ActiveDirectory'
        }
        # At once: the panels of the results at zero, the services with what is known. No Tenant panel yet:
        # without a Graph session there may be no tenant to read, so it waits for the account.
        $screen = & $right
        $screen | Should -Match '╭─ Results ─+ starting… ─╮'
        $screen | Should -Match '╭─ Failed so far ─+ 0 ─╮'
        $screen | Should -Not -Match 'Tenant'
        $screen | Should -Match '╭─ Connections ─+ checking… ─╮'
        # Graph first, the others by name; a service that is only listed when connected is not here yet.
        $screen | Should -Match '│ ○ Graph +○ Exchange Online +│\n│ [⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Teams +│'
        $screen | Should -Not -Match 'Active Directory'

        & $step 'Account' @{ TenantId = 'id'; Account = 'merill@contoso.com'; AuthType = 'Delegated'; Graph = $true }
        $screen = & $right
        $screen | Should -Match '│ Reading the tenant… +│\n│ merill@contoso\.com · Delegated +│'
        $screen | Should -Match '│ ● Graph '

        & $step 'Organization' @{ TenantName = 'Contoso'; PrimaryDomain = 'contoso.com' }
        $screen = & $right
        $screen | Should -Match '│ Contoso +contoso\.com │\n│ merill@contoso\.com · Delegated +│'
        $screen | Should -Match '╭─ Connections ─+ checking… ─╮'

        & $step 'Service' @{ Name = 'Teams'; Connected = $false }
        $screen = & $right
        $screen | Should -Match '│ ○ Teams '
        $screen | Should -Match '╭─ Connections ─+ 1 of 3 ─╮'
        & $step 'Service' @{ Name = 'ExchangeOnline'; Connected = $true }
        (& $right) | Should -Match '╭─ Connections ─+ 2 of 3 ─╮'
        # A step for a service that is not in the panel changes nothing and does not fail.
        { & $step 'Service' @{ Name = 'ActiveDirectory'; Connected = $true } } | Should -Not -Throw
        $renderer.Close()
    }

    It 'Lists the services as soon as the dashboard opens, before the tests say which they need, and keeps the answers it had' {
        $renderer = New-PanelRenderer
        $right = { @($renderer.GetPlainScreen(160, 44) | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' }) -join "`n" }
        $step = InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            Mock Test-MtModuleImported { $false }
            Mock Get-MgContext { [pscustomobject]@{ Account = 'merill@contoso.com'; AuthType = 'Delegated' } }
            Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck
            Start-MtDashboardTenant -Renderer $r -Console $c
        }
        $screen = & $right
        # Every service that is checked on its own: Dataverse is known through Graph, Active Directory only when connected.
        foreach ($name in 'Graph', 'Azure', 'Azure DevOps', 'Exchange Online', 'GitHub', 'Security & Compliance', 'SharePoint Online', 'Teams') {
            $screen | Should -Match ([regex]::Escape($name))
        }
        $screen | Should -Not -Match 'Dataverse|Active Directory'
        # Known at once: Graph from its session, and the services whose module is not loaded.
        $screen | Should -Match '● Graph'
        $screen | Should -Match '○ Exchange Online'
        $screen | Should -Match '○ Teams'
        # Asked later: Azure, Azure DevOps and GitHub.
        $screen | Should -Match '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Azure '
        $screen | Should -Match '│ Reading the tenant… +│\n│ merill@contoso\.com · Delegated +│'
        & $step 'Service' @{ Name = 'Azure'; Connected = $true }

        # Once the tests say which services they need, the list is those, with the answers it had.
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            Mock Test-MtModuleImported { $true }
            $null = Start-MtDashboardTenant -Renderer $r -Console $c -Service 'Graph', 'Azure', 'Teams'
        }
        $panel = ((& $right) -split "`n" | Where-Object { $_ -match '^[│╭╰]' }) -join "`n"
        $panel = [regex]::Match($panel, '╭─ Connections[^\n]*(\n│[^\n]*)*').Value
        $panel | Should -Match '╭─ Connections ─+ 2 of 3 ─╮'
        $panel | Should -Match '│ ● Graph +● Azure +│'
        $panel | Should -Match '○ Teams'
        $panel | Should -Not -Match 'Exchange Online|Azure DevOps|GitHub'
        $renderer.Close()
    }

    It 'Has no step for a dashboard that does not own the screen' {
        $plain = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
        InModuleScope Maester -Parameters @{ r = $plain; c = $script:wide } { param($r, $c) Start-MtDashboardTenant -Renderer $r -Console $c -Service 'Graph' } | Should -BeNullOrEmpty
    }

    It 'Puts the links of the project in the status bar' {
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } { param($r, $c) Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck }
        $screen = $renderer.GetPlainScreen(160, 44)
        # Four at the left, four at the right edge (the last the sponsor page), and the bar spans the window.
        $screen[-1] | Should -Match '^ maester\.dev  Docs │ Contributors │ Our Manifesto  +(⌘|Ctrl)-click to open  +Star on GitHub │ Discord │ Issues │ Sponsor ♥ $'
        $screen[-1].Length | Should -Be 159
        $renderer.Close()
    }

    It 'Reads the keys of the dashboard only when it owns the screen and a person is at the console' {
        # A console that is too small for the dashboard: the compact layout reads no keys.
        $small = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
        $small.Width = 60; $small.Height = 10; $small.RefreshIntervalMs = 0; $small.FullScreen = $true
        InModuleScope Maester -Parameters @{ r = $small; c = $script:wide } { param($r, $c) Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck }
        $small.IsFullScreen | Should -BeFalse
        $small.ReadKeys | Should -BeFalse
        $small.Close()

        # PowerShell was started with -NonInteractive.
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            Mock Get-MtUserInteractive { $false }
            Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck
        }
        $renderer.ReadKeys | Should -BeFalse
        $renderer.Close()

        $renderer.GameBestPath | Should -BeNullOrEmpty

        # Otherwise it is on, unless the input is not a keyboard (redirected, as in most test runs).
        $renderer = New-PanelRenderer
        $keyboard = InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            Mock Get-MtUserInteractive { $true }
            Initialize-MtDashboard -Renderer $r -Console $c -SkipVersionCheck
            -not [System.Console]::IsInputRedirected
        }
        $renderer.ReadKeys | Should -Be $keyboard
        # With the keys comes the place of one line of the user's own, next to the cache of the blog posts.
        if ($keyboard) { $renderer.GameBestPath | Should -Be (Join-Path ([System.Environment]::GetFolderPath('LocalApplicationData')) 'Maester/run-best.txt') }
        else { $renderer.GameBestPath | Should -BeNullOrEmpty }
        # This renderer writes to a string: whatever the setting, it never reads the console.
        $renderer.Start(2)
        $renderer.KeyPollCount | Should -Be 0
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

    It 'Leaves the Tenant panel out when Graph is not connected' {
        $renderer = New-PanelRenderer
        $context = [pscustomobject]@{ TenantName = $null; Services = [pscustomobject]@{ Graph = $false; ExchangeOnline = $true } }
        InModuleScope Maester -Parameters @{ r = $renderer; c = $script:wide } {
            param($r, $c)
            Mock Get-MgContext { $null }
            $r.SetPanels([string[]]@('Tenant', 'Totals'))
            $r.Open()
            $r.Start(1)
            # Not even "Reading the tenant" while the context is read: there is no tenant to read.
            $null = Start-MtDashboardTenant -Renderer $r -Console $c
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Not -Match 'Tenant|Reading the tenant'
        $screen | Should -Match 'Results'
        InModuleScope Maester -Parameters @{ r = $renderer; t = $context } {
            param($r, $t)
            Set-MtDashboardTenant -Renderer $r -TenantContext $t
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Not -Match 'Tenant|Not connected to Microsoft Graph|Exchange Online'
        $renderer.Close()
    }

    It 'Shows the Active Directory domain, domain controller and credential account in its panel' {
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer } {
            param($r)
            $r.SetPanels([string[]]@('ActiveDirectory'))
            $r.Open()
            $savedConnection = $__MtSession.ADConnection
            $savedCredential = $__MtSession.ADCredential
            $__MtSession.ADConnection = [pscustomobject]@{ Connected = $true; ResolvedDomain = 'north.sevenkingdoms.local'; ResolvedServer = 'winterfell.north.sevenkingdoms.local'; AuthenticationMode = 'Ntlm' }
            $__MtSession.ADCredential = [pscredential]::new('NORTH\eddard.stark', [securestring]::new())
            try { Set-MtDashboardDirectory -Renderer $r } finally { $__MtSession.ADConnection = $savedConnection; $__MtSession.ADCredential = $savedCredential }
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '│ north\.sevenkingdoms\.local +winterfell │'
        $screen | Should -Match 'NORTH\\eddard\.stark · Ntlm'
        $renderer.Close()
    }

    It 'Leaves the Active Directory panel out when it is not connected' {
        $renderer = New-PanelRenderer
        InModuleScope Maester -Parameters @{ r = $renderer } {
            param($r)
            $r.SetPanels([string[]]@('ActiveDirectory'))
            $r.Open()
            $r.Start(1)
            $saved = $__MtSession.ADConnection
            $__MtSession.ADConnection = [pscustomobject]@{ Connected = $false; ResolvedDomain = 'stale.local' }
            try { Set-MtDashboardDirectory -Renderer $r } finally { $__MtSession.ADConnection = $saved }
        }
        $screen = $renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Not -BeNullOrEmpty
        $screen | Should -Not -Match 'Active Directory|stale\.local'
        $renderer.Close()
    }

    It 'Shows the tenant, its domain and the account in the Tenant panel, without the services' {
        $renderer = New-PanelRenderer
        $context = [pscustomobject]@{
            TenantName = 'Contoso'; PrimaryDomain = 'contoso.com'; TenantId = '0817c655'; Account = 'merill@contoso.com'; AuthType = 'Delegated'; Cloud = 'Commercial'; TenantType = 'Workforce'
            Services   = [pscustomobject]@{ Graph = $true; Teams = $false }
        }
        InModuleScope Maester -Parameters @{ r = $renderer; t = $context } {
            param($r, $t)
            $r.SetPanels([string[]]@('Tenant'))
            $r.Open()
            Mock Invoke-MgGraphRequest { throw 'The Tenant panel must not request anything' }
            Mock Invoke-MtGraphRequest { throw 'The Tenant panel must not request anything' }
            Set-MtDashboardTenant -Renderer $r -TenantContext $t
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

Describe 'Output box' {
    BeforeAll {
        function Get-OutputRenderer {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Unicode = $true; $renderer.Width = 100; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.SetPhases([string[]]@('Prepare', 'Run tests', 'Results', 'Reports'))
            $renderer.StartPhase('Run tests')
            $renderer
        }
    }

    It 'Shows the newest lines under the phases before the tests start, wrapped, with progress pinned at the bottom' {
        $renderer = Get-OutputRenderer
        $renderer.StartOutput('Zero Trust Assessment')
        foreach ($n in 1..60) { $renderer.WriteOutput("line $n") }
        $renderer.WriteOutput(('word ' * 40).Trim())
        $renderer.WriteOutput('Completed: 1 / 5', $true)
        $renderer.WriteOutput('Completed: 2 / 5', $true)
        $screen = $renderer.GetPlainScreen(100, 40)
        $top = [array]::FindIndex($screen, [Predicate[string]] { param($l) $l -match '╭─ Zero Trust Assessment ' })
        $top | Should -BeGreaterThan 0
        $screen[$top] | Should -Match '61 lines ─╮$'
        $screen[-1] | Should -Match '^ ╰─+╯$'
        $screen[-2] | Should -Match '^ │ . Completed: 2 / 5 +│$'
        $screen[-3] | Should -Match '^ ├╌ Progress ╌+┤$'
        ($screen -join "`n") | Should -Not -Match 'Completed: 1 / 5'
        # The long line wraps at a space, and the oldest lines have scrolled out.
        $screen[-5] | Should -Match '^ │ word( word)+ +│$'
        $screen[-6] | Should -Match '^ │ word( word)+ +│$'
        $screen[-7] | Should -Match '^ │ line 60 +│$'
        ($screen -join "`n") | Should -Not -Match 'line 1 '
        @($screen | ForEach-Object { $_.Length } | Sort-Object -Unique) | Should -Not -Contain 101
    }

    It 'Sits between the result blocks and the running tests while tests run, and goes when it is stopped' {
        $renderer = Get-OutputRenderer
        $renderer.Start(2, [string[]]@('Entra'), [int[]]@(2), [string[]]@($null))
        $renderer.ItemStarting('MT.1', 'A long test', 'Entra')
        $renderer.WriteOutput('from the tool')
        $screen = $renderer.GetPlainScreen(100, 40)
        $box = [array]::FindIndex($screen, [Predicate[string]] { param($l) $l -match '╭─ Output ' })
        $running = [array]::FindIndex($screen, [Predicate[string]] { param($l) $l -match '╭─ Running ' })
        $box | Should -BeGreaterThan 0
        $running | Should -Be ($box + 10)
        $screen[$box + 1] | Should -Match '│ from the tool +│'
        $renderer.HasOutput | Should -BeTrue
        $renderer.StopOutput()
        $renderer.HasOutput | Should -BeFalse
        ($renderer.GetPlainScreen(100, 40) -join "`n") | Should -Not -Match 'from the tool'
    }

    It 'Removes escape sequences, control characters and emoji from what other programs write' {
        [Maester.Engine.MtConsoleRenderer]::OutputText("$([char]27)[32m🚀 Started$([char]27)[0m") | Should -Be 'Started'
        [Maester.Engine.MtConsoleRenderer]::OutputText("`tindented$([char]7) ✅ done") | Should -Be '    indented done'
        [Maester.Engine.MtConsoleRenderer]::OutputText("a$([char]0x202E)b") | Should -Be 'ab'
    }
}

Describe 'Write-MtTestOutput' {
    AfterEach {
        InModuleScope Maester { $script:__MtConsoleRenderer = $null; $script:__MtTestOutput = $null }
    }

    It 'Hands the lines to the dashboard while it owns the screen, and closes the box with -Complete' {
        $result = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 100; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            $written = @("first`nsecond", [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('from stderr'), 'E', 'NotSpecified', $null) |
                    Write-MtTestOutput -Title 'The tool' 6>&1)
            $screen = $renderer.GetPlainScreen(100, 40) -join "`n"
            Write-MtTestOutput -Complete
            [pscustomobject]@{ Written = $written.Count; Screen = $screen; Open = $renderer.HasOutput }
        }
        $result.Written | Should -Be 0
        $result.Screen | Should -Match '╭─ The tool .*3 lines'
        $result.Screen | Should -Match '│ first '
        $result.Screen | Should -Match '│ second '
        $result.Screen | Should -Match '│ from stderr '
        $result.Open | Should -BeFalse
    }

    It 'Writes the lines to the host, indented, without the dashboard, and progress at most every ten seconds' {
        # In CI, so that a line from the tool cannot issue a workflow command.
        $ci = $script:stream.PSObject.Copy()
        $ci.CI = 'GitHubActions'
        $lines = InModuleScope Maester -Parameters @{ c = $ci } {
            param($c)
            $__MtSession.Console = $c
            $script:hostLines = [System.Collections.Generic.List[string]]::new()
            Mock Write-MtHostLine { $script:hostLines.Add($Text) }
            try {
                $streamed = @(
                    Write-MtTestOutput -Title 'The tool' -InputObject "one$([char]27)[31m" 6>&1
                    Write-MtTestOutput 'Completed: 1 / 5' -Progress 6>&1
                    Write-MtTestOutput 'Completed: 2 / 5' -Progress 6>&1
                    Write-MtTestOutput '::error::not a command' 6>&1
                )
                # Nothing goes to a stream, which the engine would hold until the test has finished.
                if ($streamed.Count -gt 0) { throw "Wrote $($streamed.Count) records to a stream." }
                $script:hostLines
            } finally { $__MtSession.Console = $null }
        }
        $lines | Should -Be @('  The tool', '    one', '    Completed: 1 / 5', '    : :error::not a command')
    }
}

Describe 'Write-MtTestProgress' {
    AfterEach {
        InModuleScope Maester { $script:__MtConsoleRenderer = $null; $script:__MtTestOutput = $null }
    }

    It 'Shows the stage, a bar of the items done, the items running and the errors at the top of the box' {
        $screen = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 100; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            Write-MtTestOutput -Title 'The tool' -InputObject 'a line of the log'
            Write-MtTestProgress -Stage 'Exporting data' -StageNumber 1 -StageCount 3 -Completed 12 -Total 40 -Failed 1 -Running 2 -Current 'Users', 'Groups'
            Write-MtTestProgress -ErrorMessage 'The export of Devices failed'
            $renderer.GetPlainScreen(100, 40) -join "`n"
            Write-MtTestOutput -Complete
        }
        $screen | Should -Match '╭─ The tool .*1 line · 1 error'
        $screen | Should -Match '│ Stage 1 of 3 · Exporting data '
        $screen | Should -Match '│ ━+─+ 13 / 40 32% · 1 failed · 2 running '
        $screen | Should -Match '│ . Users, Groups '
        $screen | Should -Match '│ ✗ The export of Devices failed '
        $screen | Should -Match '├╌ Log ╌'
        $screen | Should -Match '│ a line of the log '
    }

    It 'Draws the stages as a track, and lists the items running and those that finished as it lists the tests' {
        $screen = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 100; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            Write-MtTestOutput -Title 'The tool' -InputObject 'a line of the log'
            Write-MtTestProgress -Stages 'Export', 'Tests', 'Report' -StageNumber 2 -Stage 'Running tests' -Completed 1 -Failed 1 -Total 10 -Items @(
                @{ Id = 'T.1'; Title = 'The first test'; Status = 'Passed'; Seconds = 2.5 }
                @{ Id = 'T.2'; Title = 'The second test'; Status = 'Failed'; Detail = 'Forbidden'; Seconds = 0.5 }
                @{ id = 'T.3'; title = 'The third test'; detail = 'Reading policies'; seconds = 12 }
            )
            $renderer.GetPlainScreen(100, 40) -join "`n"
            Write-MtTestOutput -Complete
        }
        $screen | Should -Match '│ ✓ 1 Export ━━ ● 2 Tests ┄┄ ○ 3 Report '
        $screen | Should -Match '│ Running tests  ━+─+ 2 / 10 20% · 1 failed'
        $screen | Should -Match '│ . T\.3 +The third test  Reading policies +12\.0s │'
        $screen | Should -Match '│ ✗ T\.2 +The second test  Forbidden +0\.5s │'
        $screen | Should -Match '│ ✓ T\.1 +The first test +2\.5s │'
        # The one running first, then those that finished, the newest first.
        $screen.IndexOf('T.3') | Should -BeLessThan $screen.IndexOf('T.2')
        $screen.IndexOf('T.2') | Should -BeLessThan $screen.IndexOf('T.1')
    }

    It 'Takes its progress and errors from ##maester lines of the output, which are not shown as lines' {
        $result = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 100; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            @(
                'before'
                '##maester[progress] {"Stage":"Running tests","completed":3,"TOTAL":9,"current":"21828","unknown":true}'
                "##maester[error] Test 21829 failed`nafter"
                '##maester[progress] not json'
            ) | Write-MtTestOutput -Title 'The tool'
            [pscustomobject]@{ Screen = $renderer.GetPlainScreen(100, 40) -join "`n" }
            Write-MtTestOutput -Complete
        }
        $result.Screen | Should -Match '│ Running tests '
        $result.Screen | Should -Match ' 3 / 9 '
        $result.Screen | Should -Match '│ . 21828 '
        $result.Screen | Should -Match '│ ✗ Test 21829 failed '
        $result.Screen | Should -Match '2 lines · 1 error'
        $result.Screen | Should -Not -Match '##maester'
    }

    It 'Shows the results, the groups and the times of the work in the box in place of the run''s, before its tests start' {
        $screens = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 165; $renderer.Height = 50; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Unicode = $true; $renderer.Ansi = $false
            $renderer.SetPanels([string[]]@('Totals', 'Slowest', 'Pace', 'Results'))
            $renderer.SetRunLogo([string[]]@(' __  __ ', '|  \/  |', '| |\/| |', '|_|  |_|', ''), 9, 4, '', 'v3')
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            Write-MtTestOutput -Title 'The assessment' -InputObject 'a line of the log'
            @(
                '##maester[progress] {"stage":"Running tests","stageNumber":2,"stageCount":3,"total":20,"completed":6,'
                '"items":[{"id":"T.1","status":"Passed","seconds":2},{"id":"T.2","title":"The slow one","status":"Passed","seconds":40},{"id":"T.3","seconds":1}],'
                '"results":{"name":"Zero Trust","passed":4,"failed":2,"running":1,"total":20},"groupLabel":"Zero Trust Pillars",'
                '"groups":[{"name":"Identity","passed":3,"failed":1,"total":12,"running":1},{"name":"Devices","passed":1,"failed":1,"total":8}]}'
            ) -join '' | Write-MtTestOutput
            $renderer.GetPlainScreen(165, 50) -join "`n"
            Write-MtTestOutput -Complete
            $renderer.GetPlainScreen(165, 50) -join "`n"
        }
        $screen = $screens[0]
        # The groups where the products are listed, with their counts.
        $screen | Should -Match '╭─ Zero Trust Pillars ─'
        $screen | Should -Match '│ Identity +━+─+ +4/12  ✓ 3 +✗ 1 .* 1 running'
        $screen | Should -Match '│ Devices +━+─+ +2/8  ✓ 1 +✗ 1 '
        # The results in the Results panel and the result blocks, under the work's name.
        $screen | Should -Match '╭─ Zero Trust ─+ 6 of 20 ─╮'
        $screen | Should -Match '✓ 4 passed 67% +✗ 2 failed 33%'
        $screen | Should -Match '│ ■{6}⠲□{13} '
        # The times of the items that finished: the Pace graph by the logo, and the Slowest panel.
        $screen | Should -Match 'how long each item took'
        $screen | Should -Match 'longest 40\.0s'
        $screen | Should -Match '│ T\.2 +The slow one +40\.0s │'
        $screen | Should -Not -Match '╭─ Products'
        # Once the work is done, the run's own panels come back.
        $screens[1] | Should -Not -Match 'Zero Trust Pillars|Identity|The slow one'
    }

    It 'Lists the whole name of an item without a title, and only the items of the newest stage, in the Slowest panel' {
        $screens = InModuleScope Maester {
            $renderer = [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new())
            $renderer.Width = 165; $renderer.Height = 50; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
            $renderer.Unicode = $true; $renderer.Ansi = $false
            $renderer.SetPanels([string[]]@('Totals', 'Slowest', 'Pace', 'Results'))
            $renderer.Open()
            $script:__MtConsoleRenderer = $renderer
            Write-MtTestOutput -Title 'The assessment' -InputObject 'a line of the log'
            Write-MtTestProgress -Stage 'Exporting' -StageNumber 1 -StageCount 2 -Completed 1 -Total 4 -Items @{ Id = 'ConfigurationPolicy'; Status = 'Passed'; Seconds = 50 }
            $renderer.GetPlainScreen(165, 50) -join "`n"
            Write-MtTestProgress -Stage 'Testing' -StageNumber 2 -StageCount 2 -Completed 0 -Total 9
            $renderer.GetPlainScreen(165, 50) -join "`n"
            Write-MtTestProgress -Stage 'Testing' -StageNumber 2 -StageCount 2 -Completed 1 -Total 9 -Items @{ Id = 'T.1'; Title = 'The first'; Status = 'Passed'; Seconds = 2 }
            $renderer.GetPlainScreen(165, 50) -join "`n"
            Write-MtTestProgress -Stage 'Done' -StageNumber 3 -StageCount 2
            $renderer.GetPlainScreen(165, 50) -join "`n"
            Write-MtTestOutput -Complete
        }
        $screens[0] | Should -Match '│ ConfigurationPolicy +50\.0s │'
        # Until a test of the next stage finishes, the panel keeps the stage before it.
        $screens[1] | Should -Match '│ ConfigurationPolicy +50\.0s │'
        $screens[2] | Should -Match '│ T\.1 +The first +2\.0s │'
        $screens[2] | Should -Not -Match '│ ConfigurationPolicy'
        $screens[3] | Should -Match '│ T\.1 +The first +2\.0s │'
    }

    It 'Writes the stage when it changes, the counts at most every ten seconds and each error, without the dashboard' {
        $ci = $script:stream.PSObject.Copy()
        $ci.CI = 'GitHubActions'
        $lines = InModuleScope Maester -Parameters @{ c = $ci } {
            param($c)
            $__MtSession.Console = $c
            $script:hostLines = [System.Collections.Generic.List[string]]::new()
            Mock Write-MtHostLine { $script:hostLines.Add($Text) }
            try {
                Write-MtTestProgress -Stage 'Exporting' -StageNumber 1 -StageCount 2 -Completed 1 -Total 4
                Write-MtTestProgress -Stage 'Exporting' -StageNumber 1 -StageCount 2 -Completed 2 -Total 4
                Write-MtTestProgress -ErrorMessage 'Users failed'
                Write-MtTestProgress -Stage 'Testing' -StageNumber 2 -StageCount 2 -Completed 0 -Total 9
                Write-MtTestProgress -Stage 'Testing' -StageNumber 2 -StageCount 2 -Completed 1 -Total 9 -Items @{ Id = 'T.1'; Title = 'The first'; Status = 'Passed'; Seconds = 2 }, @{ Id = 'T.2'; Seconds = 1 }
                Write-MtTestProgress -Stage 'Testing' -StageNumber 2 -StageCount 2 -Completed 1 -Total 9 -Items @{ Id = 'T.1'; Title = 'The first'; Status = 'Passed'; Seconds = 2 }
                $script:hostLines -replace "`e\[[0-9;]*m", ''
            } finally { $__MtSession.Console = $null }
        }
        $lines | Should -Be @('    Stage 1 of 2 · Exporting', '    1 / 4', '    Error: Users failed', '    Stage 2 of 2 · Testing', '    0 / 9', "    $($ci.Unicode ? '✓' : '+') T.1 The first  2.0 s")
    }
}
