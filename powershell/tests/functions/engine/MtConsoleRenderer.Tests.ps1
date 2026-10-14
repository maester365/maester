BeforeAll {
    # Engine DLL only, as Invoke-MtEngineRun.Tests.ps1: the build-engine workflow runs these on every OS.
    Import-Module "$PSScriptRoot/../../../lib/Maester.Engine.dll" -Force

    $script:esc = [char]27

    function New-TestRenderer {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([int] $Width = 100, [switch] $Ascii, [switch] $NoColor, [switch] $Taskbar)
        $writer = [System.IO.StringWriter]::new()
        $renderer = [Maester.Engine.MtConsoleRenderer]::new($writer)
        $renderer.Width = $Width
        $renderer.RefreshIntervalMs = 0 # no timer: frames are drawn on events only, so output is deterministic
        $renderer.Unicode = -not $Ascii
        $renderer.Ansi = -not $NoColor
        $renderer.TaskbarProgress = [bool]$Taskbar
        [pscustomobject]@{ Renderer = $renderer; Writer = $writer }
    }

    $script:fixtureModule = New-Module -Name MtRendererFixture -ScriptBlock {
        function Test-Warning { [CmdletBinding()] param() Write-Warning 'careful'; $true }
        function Test-Quiet { [CmdletBinding()] param() $ProgressPreference }
        Export-ModuleMember -Function @()
    }
}

Describe 'MtConsoleRenderer live region' {
    It 'Counts each Maester result and shows done/total' {
        $t = New-TestRenderer
        $t.Renderer.Start(6)
        'Passed', 'Passed', 'Failed', 'Error', 'Investigate', 'Skipped' | ForEach-Object { $t.Renderer.ItemFinished($_) }
        $t.Renderer.Passed | Should -Be 2
        $t.Renderer.Failed | Should -Be 1
        $t.Renderer.Errors | Should -Be 1
        $t.Renderer.Investigate | Should -Be 1
        $t.Renderer.Skipped | Should -Be 1
        $line = $t.Renderer.GetPlainFrame(100)[0]
        $line | Should -Match '✓ 2  ✗ 1  ! 1  \? 1  – 1'
        $line | Should -Match '6/6  100%'
        $t.Renderer.Stop()
    }

    It 'Shows the running test and its title on the second line' {
        $t = New-TestRenderer
        $t.Renderer.Start(3)
        $t.Renderer.ItemStarting('MT.1001', 'Conditional Access requires MFA')
        $t.Renderer.GetPlainFrame(100)[1] | Should -Match '^  MT\.1001  Conditional Access requires MFA \(0:00\)$'
        $t.Renderer.ItemFinished('Passed')
        $t.Renderer.GetPlainFrame(100)[1] | Should -Match 'Running tests'
        $t.Renderer.Stop()
    }

    It 'Never draws a line as wide as the console (width <Width>)' -ForEach @(@{ Width = 30 }, @{ Width = 60 }, @{ Width = 120 }) {
        $t = New-TestRenderer -Width $Width
        $t.Renderer.Start(500)
        $t.Renderer.ItemStarting('CONTOSO.123', ('A very long test title ' * 10))
        foreach ($line in $t.Renderer.GetPlainFrame($Width)) { $line.Length | Should -BeLessThan $Width }
        $t.Renderer.Stop()
    }

    It 'Uses ASCII symbols when Unicode is off' {
        $t = New-TestRenderer -Ascii
        $t.Renderer.Start(2)
        $t.Renderer.ItemFinished('Passed')
        $t.Renderer.ItemFinished('Failed')
        $frame = $t.Renderer.GetPlainFrame(100) -join "`n"
        $frame | Should -Match '\+ 1  x 1'
        $frame | Should -Not -Match '[✓✗–━⠋]'
        $t.Renderer.Stop()
    }

    It 'Writes no colour when Ansi is off' {
        $t = New-TestRenderer -NoColor
        $t.Renderer.Start(1)
        $t.Renderer.ItemFinished('Failed')
        $t.Renderer.Stop()
        $t.Writer.ToString() | Should -Not -Match "$esc\[3\dm"
    }

    It 'Erases the region on Pause and draws nothing until Resume' {
        $t = New-TestRenderer
        $t.Renderer.Start(2)
        $t.Renderer.Pause()
        $before = $t.Writer.ToString().Length
        $t.Renderer.ItemFinished('Passed') # counted, but not drawn while paused
        $t.Writer.ToString().Length | Should -Be $before
        $t.Renderer.Resume()
        $t.Writer.ToString().Substring($before) | Should -Match '✓ 1'
        $t.Renderer.Stop()
    }

    It 'Erases as many rows as the last frame takes at the current width' {
        $t = New-TestRenderer -Width 100
        $t.Renderer.Start(2)
        $t.Renderer.ItemStarting('MT.1', ('x' * 80))
        $t.Renderer.Width = 40 # the console got narrower: the drawn lines now wrap
        $mark = $t.Writer.ToString().Length
        $t.Renderer.Pause()
        $erase = $t.Writer.ToString().Substring($mark)
        ([regex]::Matches($erase, "$esc\[1A")).Count | Should -BeGreaterThan 1
        $t.Renderer.Resume()
        $t.Renderer.Stop()
    }

    It 'Restores the cursor on Stop, and Stop can be called twice' {
        $t = New-TestRenderer
        $t.Renderer.Start(1)
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?25l"))
        $t.Renderer.Stop()
        $t.Renderer.Stop()
        $t.Renderer.IsRunning | Should -BeFalse
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?25h") + '$')
    }

    It 'Reports taskbar progress with OSC 9;4 and clears it on Stop' {
        $t = New-TestRenderer -Taskbar
        $t.Renderer.Start(4)
        $t.Renderer.ItemFinished('Passed')
        $t.Renderer.Stop()
        $out = $t.Writer.ToString()
        $out | Should -Match ([regex]::Escape("$esc]9;4;1;25"))
        $out | Should -Match ([regex]::Escape("$esc]9;4;0;0"))
    }
}

Describe 'MtConsoleRenderer status line' {
    It 'Draws the phase on one line and leaves the cursor at its start' {
        $t = New-TestRenderer
        $t.Renderer.ShowStatus('Reading the tenant context')
        $t.Writer.ToString() | Should -Match 'Reading the tenant context…[^\r]*\r$'
    }

    It 'Erases the status line when it is cleared, paused or stopped' {
        $t = New-TestRenderer
        $t.Renderer.ShowStatus('Discovering tests')
        $mark = $t.Writer.ToString().Length
        $t.Renderer.Pause()
        $t.Writer.ToString().Substring($mark) | Should -Be "`r$esc[2K"
        $t.Renderer.Resume()
        $t.Writer.ToString() | Should -Match 'Discovering tests…[^\r]*\r$'
        $t.Renderer.ShowStatus($null)
        $t.Writer.ToString() | Should -Match ([regex]::Escape("`r$esc[2K") + '$')
        $t.Renderer.Stop() # nothing left to erase
        $t.Writer.ToString() | Should -Match ([regex]::Escape("`r$esc[2K") + '$')
    }

    It 'Replaces the status line when the live region starts' {
        $t = New-TestRenderer
        $t.Renderer.ShowStatus('Discovering tests')
        $mark = $t.Writer.ToString().Length
        $t.Renderer.Start(1)
        $t.Writer.ToString().Substring($mark) | Should -Match ('^' + [regex]::Escape("`r$esc[2K"))
        $t.Renderer.Stop()
    }
}

Describe 'Invoke-MtEngineRun -Renderer' {
    It 'Pauses the region around replayed records' {
        $t = New-TestRenderer
        $t.Renderer.Start(1)
        $item = [Maester.Engine.MtWorkItem]@{ Id = 'R.1'; Command = 'Test-Warning'; Title = 'Warns' }
        $mark = $t.Writer.ToString().Length
        $null = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -Renderer $t.Renderer 3>$null
        $t.Writer.ToString().Substring($mark) | Should -Match "$esc\[2K"
        $t.Renderer.Stop()
    }

    It 'Silences Write-Progress inside tests while a renderer is drawing' {
        $t = New-TestRenderer
        $t.Renderer.Start(1)
        $item = [Maester.Engine.MtWorkItem]@{ Id = 'R.2'; Command = 'Test-Quiet' }
        $r = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -Renderer $t.Renderer -NoStreamReplay
        $t.Renderer.Stop()
        [string]$r.Output[0] | Should -Be 'SilentlyContinue'
    }

    It 'Leaves the progress preference alone without a renderer' {
        $item = [Maester.Engine.MtWorkItem]@{ Id = 'R.3'; Command = 'Test-Quiet' }
        $r = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -NoStreamReplay
        [string]$r.Output[0] | Should -Not -Be 'SilentlyContinue'
    }
}

Describe 'MtConsoleRenderer dashboard' {
    BeforeAll {
        function New-TestDashboard {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([int] $Width = 100, [int] $Height = 30)
            $t = New-TestRenderer -Width $Width
            $t.Renderer.Height = $Height
            $t.Renderer.FullScreen = $true
            $t.Renderer.SetHeader(@('BANNER 1', 'BANNER 2', 'BANNER 3'), 60, 'Maester v3')
            $t.Renderer.SetPhases(@('Prepare', 'Run tests', 'Results', 'Reports'))
            $t
        }
    }

    It 'Takes the alternate screen on Open and gives it back on Close' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.IsFullScreen | Should -BeTrue
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?1049h"))
        $t.Renderer.Close()
        $t.Renderer.Close()
        $t.Renderer.IsFullScreen | Should -BeFalse
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?25h$esc[?1049l") + '$')
    }

    It 'Stays in the compact layout when the console is too small (<Width>x<Height>)' -ForEach @(@{ Width = 100; Height = 12 }, @{ Width = 60; Height = 40 }) {
        $t = New-TestDashboard -Width $Width -Height $Height
        $t.Renderer.Open()
        $t.Renderer.IsFullScreen | Should -BeFalse
        $t.Writer.ToString() | Should -Not -Match '1049h'
        $t.Renderer.Close()
    }

    It 'Shows the phases: done with a tick, the current one, and the ones to come' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.StartPhase('Prepare')
        $t.Renderer.StartPhase('Run tests')
        $strip = $t.Renderer.GetPlainScreen(100, 30) | Where-Object { $_ -match 'Prepare' }
        $strip | Should -Match '✓ Prepare .*● Run tests .*○ Results .*○ Reports'
        $t.Renderer.Close()
    }

    It 'Shows what a phase is doing outside the test phase' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.StartPhase('Reports')
        $t.Renderer.ShowStatus('Creating html report')
        ($t.Renderer.GetPlainScreen(100, 30) -join "`n") | Should -Match 'Creating html report…'
        $t.Renderer.Close()
    }

    It 'Counts results per lane and lists every running test, as parallel runs need' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.Start(10, @('Entra ID', 'Teams', 'Azure'), [int[]]@(6, 4, 0), @($null, $null, '3 skipped'))
        $t.Renderer.ItemStarting('E.1', 'First', 'Entra ID')
        $t.Renderer.ItemStarting('T.1', 'Second', 'Teams')
        $t.Renderer.ItemStarting('E.2', 'Third', 'Entra ID')
        $t.Renderer.ItemFinished('T.1', 'Failed')   # finishes out of order
        $screen = $t.Renderer.GetPlainScreen(100, 30)
        ($screen | Where-Object { $_ -match '^ Entra ID' }) | Should -Match '0/6 .* 2 running'
        ($screen | Where-Object { $_ -match '^ Teams' }) | Should -Match '1/4 .*✗ 1'
        # A product with nothing to run is on the line of the skipped ones, not in a lane.
        @($screen | Where-Object { $_ -match '^ Azure' }).Count | Should -Be 0
        ($screen | Where-Object { $_ -match '^ – Skipped' }) | Should -Match 'Azure \(3\)'
        ($screen | Where-Object { $_ -match '^ Running' }) | Should -Match '2 tests'
        @($screen | Where-Object { $_ -match ' (E\.1|E\.2) ' }).Count | Should -Be 2
        # The test that finished is no longer running: it is listed under the running ones, with its result.
        $running = [array]::IndexOf($screen, ($screen | Where-Object { $_ -match '^ Running' }))
        $screen[$running + 3] | Should -Match '^ ✗ T\.1 +Second +[\d.]+s$'
        $t.Renderer.Failed | Should -Be 1
        $t.Renderer.Close()
    }

    It 'Shows the banner while the run prepares, and one line with the phases once the tests start' {
        $t = New-TestDashboard -Height 40
        $t.Renderer.Open()
        $t.Renderer.StartPhase('Prepare')
        $t.Renderer.ShowStatus('Reading the tenant context')
        $before = $t.Renderer.GetPlainScreen(100, 40)
        $before[0..2] | Should -Be @('BANNER 1', 'BANNER 2', 'BANNER 3')
        ($before -join "`n") | Should -Match '\n ● Prepare [\d.]+s  ─  ○ Run tests'
        $t.Renderer.StartPhase('Run tests')
        $t.Renderer.Start(10)
        $after = $t.Renderer.GetPlainScreen(100, 40)
        ($after -join "`n") | Should -Not -Match 'BANNER'
        $after[0] | Should -Match '^ Maester v3 {2,}✓ Prepare [\d.]+s  ─  ● Run tests [\d.]+s  ─  ○ Results  ─  ○ Reports$'
        $after[0].Length | Should -Be 99
        # It stays one line for the rest of the run.
        1..10 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
        $t.Renderer.Stop()
        $t.Renderer.StartPhase('Results')
        ($t.Renderer.GetPlainScreen(100, 40) -join "`n") | Should -Not -Match 'BANNER'
        $t.Renderer.Close()
    }

    It 'Writes the name in the colours of the wordmark in the one-line header' {
        $t = New-TestDashboard -Height 40
        $t.Renderer.TrueColor = $true
        $t.Renderer.SetHeaderTagline(1, 'FLAME  ', 44, 'v3.0.0', 'maester.dev', 'https://maester.dev')
        $t.Renderer.Open()
        $t.Renderer.Start(10)
        $t.Renderer.GetPlainScreen(100, 40)[0] | Should -Match '^ MAESTER v3\.0\.0 {2,}○ Prepare'
        $out = $t.Writer.ToString()
        $out | Should -Match ([regex]::Escape("$esc[1;38;2;229;36;59mM"))
        $out | Should -Match ([regex]::Escape("$esc[1;38;2;255;181;71mR"))
        $t.Renderer.Close()
    }

    It 'Uses the one-line header and hides lanes when the console is short, and never draws more rows than it has' {
        $t = New-TestDashboard -Height 16
        $t.Renderer.Open()
        $names = 1..9 | ForEach-Object { "Product $_" }
        $t.Renderer.Start(90, [string[]]$names, [int[]]@(1..9 | ForEach-Object { 10 }), $null)
        $t.Renderer.ItemStarting('P.1', 'Running one', 'Product 7')
        $screen = $t.Renderer.GetPlainScreen(100, 16)
        $screen.Count | Should -BeLessThan 16
        # One line: the name, and the phases at its right.
        $screen[0] | Should -Match '^ Maester v3 {2,}○ Prepare  ─  ○ Run tests  ─  ○ Results  ─  ○ Reports$'
        ($screen -join "`n") | Should -Not -Match 'BANNER'
        ($screen -join "`n") | Should -Match 'Product 7'
        ($screen -join "`n") | Should -Match 'and \d+ more'
        foreach ($line in $screen) { $line.Length | Should -BeLessThan 100 }
        $t.Renderer.Close()
    }

    It 'Keeps the dashboard after Stop, for the phases that follow' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.Start(1)
        $t.Renderer.ItemFinished('Passed')
        $t.Renderer.Stop()
        $t.Renderer.IsRunning | Should -BeFalse
        $t.Renderer.IsFullScreen | Should -BeTrue
        $t.Writer.ToString() | Should -Not -Match '1049l'
        $t.Renderer.Close()
    }

    It 'Leaves the records of a test on the result instead of replaying them over the dashboard' {
        $t = New-TestDashboard
        $t.Renderer.Open()
        $t.Renderer.Start(1)
        $item = [Maester.Engine.MtWorkItem]@{ Id = 'R.9'; Command = 'Test-Warning'; Title = 'Warns'; Group = 'Entra ID' }
        $warnings = $null
        $r = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -Renderer $t.Renderer -WarningVariable warnings -WarningAction SilentlyContinue
        $t.Renderer.Close()
        $warnings | Should -BeNullOrEmpty
        $r.Warnings.Count | Should -Be 1
    }
}

Describe 'MtConsoleRenderer panels' {
    BeforeAll {
        function New-TestPanelDashboard {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([int] $Width = 160, [string[]] $Panels = @('Tenant', 'Failed', 'Drift', 'Pace', 'Tips', 'Results'))
            $t = New-TestRenderer -Width $Width
            $t.Renderer.Height = 44
            $t.Renderer.FullScreen = $true
            $t.Renderer.SetPanels($Panels)
            $t.Renderer.SetInfo(' Contoso · Graph', 16)
            $t.Renderer.Open()
            $t
        }
    }

    It 'Puts the panels in a right column on a wide console, and leaves them out on a narrow one' {
        $t = New-TestPanelDashboard
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso', 'merill@contoso.com'))
        $wide = $t.Renderer.GetPlainScreen(160, 44)
        ($wide | Where-Object { $_ -match '╭─ Tenant ─+╮$' }).IndexOf('Tenant') | Should -BeGreaterThan 98
        ($wide -join "`n") | Should -Match 'merill@contoso\.com'
        ($t.Renderer.GetPlainScreen(120, 44) -join "`n") | Should -Not -Match 'merill@contoso\.com'
        $t.Renderer.Close()
    }

    It 'Shows the connection line under the banner whether or not the Tenant panel is shown' {
        $t = New-TestPanelDashboard
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso'))
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match 'Contoso · Graph'
        ($t.Renderer.GetPlainScreen(120, 44) -join "`n") | Should -Match 'Contoso · Graph'
        $t.Renderer.Close()
    }

    It 'Shows only the panels it was given, in their order' {
        $t = New-TestPanelDashboard -Panels 'Connections', 'Tenant'
        $t.Renderer.SetConnections(@('Graph'), [bool[]]@($true))
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso'))
        $t.Renderer.Start(2)
        $t.Renderer.ItemFinished('Failed')
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen.IndexOf('Connections') | Should -BeLessThan $screen.IndexOf('Tenant')
        $screen | Should -Not -Match 'Failed so far'
        $screen | Should -Not -Match '[■□]'
        $t.Renderer.Close()
    }

    It 'Counts failed tests by severity' {
        $t = New-TestPanelDashboard
        $t.Renderer.Start(4)
        $t.Renderer.ItemFinished('A.1', 'Failed', 'Critical')
        $t.Renderer.ItemFinished('A.2', 'Failed', 'critical')
        $t.Renderer.ItemFinished('A.3', 'Failed', 'Medium')
        $t.Renderer.ItemFinished('A.4', 'Passed', 'High')
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        ($screen | Where-Object { $_ -match 'Failed so far' }) | Should -Match '╭─ Failed so far ─+ 3 ─╮$'
        ($screen | Where-Object { $_ -match ' Critical ' }) | Should -Match '█+\s+2 │$'
        ($screen | Where-Object { $_ -match ' High ' }) | Should -Match '\s0 │$'
        ($screen | Where-Object { $_ -match ' Medium ' }) | Should -Match '█+.?\s+1 │$'
        $t.Renderer.Close()
    }

    It 'Fills one square per finished test in the results chart' {
        $t = New-TestPanelDashboard
        $t.Renderer.Ansi = $false
        $t.Renderer.Start(10)
        1..4 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
        $chart = $t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[■□]' }
        ([regex]::Matches($chart, '■')).Count | Should -Be 4
        ([regex]::Matches($chart, '□')).Count | Should -Be 6
        $t.Renderer.Close()
    }

    It 'Groups tests into squares when there are more than fit, and says how many' {
        $t = New-TestPanelDashboard
        $t.Renderer.Start(2000)
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match 'each square is \d+ tests'
        $t.Renderer.Close()
    }

    It 'Reports drift against the results of an earlier run' {
        $t = New-TestPanelDashboard
        $before = [System.Collections.Generic.Dictionary[string, string]]::new()
        $before['A.1'] = 'Passed'; $before['A.2'] = 'Failed'; $before['A.3'] = 'Passed'
        $t.Renderer.Start(4)
        $t.Renderer.ItemFinished('A.1', 'Failed', 'High')   # finished before the baseline arrived
        $t.Renderer.SetBaseline($before, 'Oct 9, 08:12')
        $t.Renderer.ItemFinished('A.2', 'Passed', 'High')
        $t.Renderer.ItemFinished('A.3', 'Passed', 'High')
        $t.Renderer.ItemFinished('A.4', 'Passed', 'High')
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '╭─ Drift since last run ─+ Oct 9, 08:12 ─╮'
        $screen | Should -Match '1 newly failing'
        $screen | Should -Match 'A\.1'
        $screen | Should -Match '1 fixed'
        $screen | Should -Match '1 new test\b'
        # What the earlier run found: two passed, one failed, none to investigate.
        $screen | Should -Match '│ ✓ 2  ✗ 1  \? 0 '
        $t.Renderer.Close()
    }

    It 'Shows the small logo and the Pace graph in a band at the top while tests run' {
        $t = New-TestPanelDashboard -Panels 'Pace', 'Results'
        $t.Renderer.SetHeader(@('BANNER 1', 'BANNER 2'), 30, 'Maester v3')
        $t.Renderer.SetRunLogo(@('L0', 'L1 WORDMARK', 'L2 WORDMARK', 'L3  old tagline', 'L4'), 40, 3, 'L3  ', 'v3.0.0')
        $t.Renderer.SetPhases(@('Prepare', 'Run tests'))
        # While the run prepares: the banner, not the band.
        $t.Renderer.ShowStatus('Reading the tenant context')
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '^BANNER 1\nBANNER 2\n'
        $t.Renderer.Start(100)
        $n = 0
        foreach ($seconds in 0.05, 34, 0.4, 3, 0.0) { $n++; $t.Renderer.ItemFinished("S.$n", 'Passed', 'Low', $seconds) }
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        ($screen -join "`n") | Should -Not -Match 'BANNER'
        # Five rows: the logo at the left (40 columns), and from the 44th column four rows of graph and its caption.
        # The bars stand against the right edge of the main column, the newest at the very right.
        $screen[0] | Should -Match '^L0 +█ {3}$'
        $screen[1] | Should -Match '^L1 WORDMARK +█ ▄ $'
        $screen[2] | Should -Match '^L2 WORDMARK +█▃█ $'
        $screen[3] | Should -Match '^L3  v3\.0\.0 +▃███▁$'
        $screen[0..3] | ForEach-Object { $_.Length | Should -Be 159 }
        $screen[4] | Should -Match ('^' + 'L4'.PadRight(43) + 'how long each test took, newest on the right +[\d.]+ tests/s · longest 34\.0s$')
        $screen[4].Length | Should -Be 159
        # Under the band: the connection line of this dashboard, then the phases and right under them the
        # overall progress.
        $screen[5] | Should -Be ' Contoso · Graph'
        $screen[6] | Should -Be ''
        $screen[7] | Should -Match '^ ○ Prepare  ─  ○ Run tests$'
        $screen[8] | Should -Match '5/100 +5%'
        # The graph is in the band, so it is not under the lanes as well.
        @($screen | Where-Object { $_ -match 'how long each test took' }).Count | Should -Be 1
        # A newer version is mentioned next to the version.
        $t.Renderer.SetHeaderUpdate('v3.1.0 available', 'https://www.powershellgallery.com/packages/Maester/3.1.0')
        $t.Renderer.GetPlainScreen(160, 44)[3] | Should -Match '^L3  v3\.0\.0 · ↑ v3\.1\.0 available +▃███▁$'
        # A console that is short of rows gets the one line.
        $short = $t.Renderer.GetPlainScreen(160, 25)
        $short[0] | Should -Match '^ Maester v3 {2,}○ Prepare'
        ($short -join "`n") | Should -Not -Match 'WORDMARK'
        $t.Renderer.Close()
    }

    It 'Fills a console that is wider and taller than the standard layout' {
        $t = New-TestPanelDashboard -Width 200 -Panels 'Failed', 'Slowest', 'Results'
        $t.Renderer.Start(700)
        1..60 | ForEach-Object { $t.Renderer.ItemStarting("W.$_", "Test $_", $null); $t.Renderer.ItemFinished("W.$_", 'Failed', 'High') }
        $screen = $t.Renderer.GetPlainScreen(200, 50)
        # The right column ends at the edge of the window, and is wider than on a 160-column console.
        $boxes = @($screen | Where-Object { $_ -match '╮$' })
        $boxes.Count | Should -Be 2
        $boxes | ForEach-Object { $_.Length | Should -Be 199 }
        ($boxes[0] -replace '^.*(?=╭)').Length | Should -BeGreaterThan 58
        # One square per test: 700 squares over more rows than the standard six would hold.
        (($screen -join '') -replace '[^■□]').Length | Should -Be 700
        ($screen -join "`n") | Should -Not -Match 'each square is'
        # The Slowest panel fills the rows that are free with more tests: the column has no gap.
        @($screen | Where-Object { $_ -match '│ W\.\d+ ' }).Count | Should -BeGreaterThan 20
        @($screen | Where-Object { $_ -match '[│╮╯]$' }).Count | Should -Be 49
        $t.Renderer.Close()

        # It gives the rows back when another panel needs them: every panel is still there, and the column is full.
        $t = New-TestPanelDashboard -Width 200 -Panels 'Tenant', 'Failed', 'Slowest', 'Tips'
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('One', 'Two', 'Three'))
        $t.Renderer.SetTips(@('A tip'))
        $t.Renderer.Start(700)
        1..40 | ForEach-Object { $t.Renderer.ItemStarting("W.$_", "Test $_", $null); $t.Renderer.ItemFinished("W.$_", 'Failed', 'High') }
        $short = $t.Renderer.GetPlainScreen(200, 30)
        @($short | Where-Object { $_ -match '╭─ (Tenant|Failed so far|Slowest so far|Tip) ' }).Count | Should -Be 4
        $slow = @($short | Where-Object { $_ -match '│ W\.\d+ ' }).Count
        $slow | Should -BeGreaterThan 3
        $slow | Should -BeLessThan 40
        # No gap: every row of the column is a row of a panel.
        @($short | Where-Object { $_ -match '[│╮╯]$' }).Count | Should -Be 29
        $t.Renderer.Close()
    }

    It 'Shows a tip as its text alone, with no address under it' {
        $t = New-TestPanelDashboard -Panels 'Tips'
        $t.Renderer.SetTips(@('A tip', 'Another'))
        $t.Renderer.Start(1)
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '╭─ Tip ─+╮\n[^\n]*│ A tip +│\n[^\n]*╰'
        $t.Writer.ToString() | Should -Not -Match ([regex]::Escape("$esc]8;;"))
        $t.Renderer.Close()
    }

    It 'Shows the newest blog post as a hyperlink over two lines at most, with its date in the border' {
        $t = New-TestPanelDashboard -Panels 'Blog'
        $post = [Maester.Engine.MtBlogPost]@{ Published = 'Oct 07'; Title = 'Maester 3.0: a new test engine, and a heads-up for preview users of the automation'; Link = 'https://maester.dev/blog/3' }
        $t.Renderer.SetBlogPost($post)
        $t.Renderer.Start(1)
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        ($screen -join "`n") | Should -Match '╭─ From the blog ─+ Oct 07 ─╮'
        $lines = @($screen | Where-Object { $_ -match '│ (Maester 3\.0|preview users)' })
        $lines.Count | Should -Be 2
        ($screen -join "`n") | Should -Not -Match 'maester\.dev/blog'
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/blog/3$esc\Maester 3.0:"))
        $t.Renderer.Close()

        # A title that needs more than two lines is cut on the second.
        $long = New-TestPanelDashboard -Panels 'Blog'
        $long.Renderer.SetBlogPost([Maester.Engine.MtBlogPost]@{ Title = ('word ' * 60).Trim() })
        $long.Renderer.Start(1)
        $body = @($long.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '│ word' })
        $body.Count | Should -Be 2
        $body[1] | Should -Match '… │$'
        $long.Renderer.Close()
    }

    It 'Lays out the Tenant panel: the name and the domain on one line, the account under them' {
        $t = New-TestPanelDashboard -Panels 'Tenant'
        $t.Renderer.SetTenant('Contoso', 'contoso.com', 'merill@contoso.com · Delegated')
        $t.Renderer.Start(1)
        $box = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box.Count | Should -Be 4
        $box[1] | Should -Match '^│ Contoso +contoso\.com │$'
        $box[2] | Should -Match '^│ merill@contoso\.com · Delegated +│$'
        $t.Renderer.Close()

        # A long name is cut to keep the domain.
        $narrow = New-TestPanelDashboard -Width 142 -Panels 'Tenant'
        $narrow.Renderer.SetTenant('A tenant with a very long display name', 'contoso.onmicrosoft.com', $null)
        $narrow.Renderer.Start(1)
        $small = @($narrow.Renderer.GetPlainScreen(142, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $small.Count | Should -Be 3
        $small[1] | Should -Match '^│ A tenant.*… +contoso\.onmicrosoft\.com │$'
        $narrow.Renderer.Close()
    }

    It 'Draws the results so far as one bar split by result, with the count and the share of each under it' {
        $t = New-TestPanelDashboard -Panels 'Totals'
        $t.Renderer.Start(100)
        $empty = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $empty[0] | Should -Match '^╭─ Results ─+ 0 of 100 ─╮$'
        $empty[1] | Should -Be ('│ ' + ('░' * 54) + ' │')
        $empty[2] | Should -Match '^│ Waiting for results… +│$'

        $results = @('Passed') * 6 + @('Failed') * 2 + 'Investigate', 'Skipped'
        $n = 0
        foreach ($result in $results) { $n++; $t.Renderer.ItemStarting("R.$n", "Test $n", $null); $t.Renderer.ItemFinished("R.$n", $result, 'High') }
        $box = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box.Count | Should -Be 4
        $box[0] | Should -Match '^╭─ Results ─+ 10 of 100 ─╮$'
        # 54 cells: six tenths passed, two failed, one to investigate, one skipped. Without colour each
        # result has its own shade.
        $bar = $box[1].Substring(2, 54)
        ($bar -replace '[^█]').Length | Should -BeIn 32, 33
        ($bar -replace '[^▓]').Length | Should -BeIn 10, 11
        ($bar -replace '[^▒]').Length | Should -BeIn 5, 6
        ($bar -replace '[^░]').Length | Should -BeIn 5, 6
        $bar | Should -Match '^█+▓+▒+░+$'
        # Four results do not fit with their names and shares in 54 columns: the shares stay, the names go.
        $box[2] | Should -Match '^│ ✓ 6 60%   ✗ 2 20%   \? 1 10%   – 1 10% +│$'

        # With colour: every cell a full block in the colour of its result, and where two results meet
        # inside a cell, a partial block in the colour of the left one on that of the right one.
        $out = $t.Writer.ToString()
        $out | Should -Match "$esc\[32m█"
        $out | Should -Match "$esc\[31m█"
        $out | Should -Match "$esc\[32;41m[▏▎▍▌▋▊▉]"
        $t.Renderer.Close()
    }

    It 'Names the results under the bar when there is room for the names' {
        $t = New-TestPanelDashboard -Panels 'Totals'
        $t.Renderer.Start(300)
        1..34 | ForEach-Object { $t.Renderer.ItemFinished("P.$_", 'Passed', 'Low') }
        1..36 | ForEach-Object { $t.Renderer.ItemFinished("F.$_", 'Failed', 'High') }
        1..9 | ForEach-Object { $t.Renderer.ItemFinished("S.$_", 'Skipped', 'Low') }
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '│ ✓ 34 passed 43%   ✗ 36 failed 46%   – 9 skipped 11% +│'
        $t.Renderer.Close()
    }

    It 'Keeps one failure among hundreds of passed tests visible in the bar' {
        $t = New-TestPanelDashboard -Panels 'Totals'
        $t.Renderer.Start(300)
        1..299 | ForEach-Object { $t.Renderer.ItemFinished("P.$_", 'Passed', 'Low') }
        $t.Renderer.ItemFinished('F.1', 'Failed', 'High')
        $bar = (@($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '│$' })[0] -replace '^.*?(?=│)').Substring(2, 54)
        ($bar -replace '[^▓]').Length | Should -BeGreaterOrEqual 2
        $t.Renderer.Close()
    }

    It 'Draws the bar with plain characters when the console has no Unicode' {
        $t = New-TestPanelDashboard -Panels 'Totals'
        $t.Renderer.Unicode = $false
        $t.Renderer.Start(4)
        $t.Renderer.ItemFinished('A.1', 'Passed', 'Low')
        $t.Renderer.ItemFinished('A.2', 'Failed', 'Low')
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '\| #{27}x{27} \|'
        $screen | Should -Match '\| \+ 1 passed 50%   x 1 failed 50% +\|'
        $t.Renderer.Close()
    }

    It 'Features one contributor at a time: name, handle, what they did, and a link to their page' {
        $t = New-TestPanelDashboard -Panels 'Contributor'
        $people = [Maester.Engine.MtContributor[]]@(
            [Maester.Engine.MtContributor]@{ Name = 'Thomas Naunheim'; GitHub = 'Cloud-Architekt'; Tests = 63; Improvements = 0; Since = 2024 }
            [Maester.Engine.MtContributor]@{ Name = 'Ada Lovelace'; GitHub = 'ada-l'; Tests = 1; Improvements = 12; Since = 2025 }
            [Maester.Engine.MtContributor]@{ Name = 'New Person'; GitHub = 'newp'; Since = 2026 }
            [Maester.Engine.MtContributor]@{ Name = 'Not shown'; GitHub = 'not a handle'; Tests = 5 }
        )
        $t.Renderer.SetContributors($people, 0)
        $t.Renderer.Start(1)
        $pane = { @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' }) }
        $box = & $pane
        $box[0] | Should -Match '^╭─ Featured contributor ─+╮$'
        $box[1] | Should -Match '^│ Thomas Naunheim +@Cloud-Architekt │$'
        # A count of nothing is left out.
        $box[2] | Should -Match '^│ 63 tests · since 2024 +│$'
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/contributors/cloud-architekt$esc\"))
        # The name has the colour of the handle.
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[1;36m$esc]8;;https://maester.dev/contributors/cloud-architekt$esc\Thomas Naunheim"))
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[36m$esc]8;;https://maester.dev/contributors/cloud-architekt$esc\@Cloud-Architekt"))
        # It is the panel with the accent border.
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[36m╭─ $esc[0m$esc[1mFeatured contributor"))

        $t.Renderer.SetContributors($people, 1)
        (& $pane)[2] | Should -Match '^│ 1 test · 12 improvements · since 2025 +│$'
        $t.Renderer.SetContributors($people, 2)
        (& $pane)[2] | Should -Match '^│ Contributor since 2026 +│$'
        # The entry without a usable handle is dropped, so the fourth place is the first person again.
        $t.Renderer.SetContributors($people, 3)
        (& $pane)[1] | Should -Match 'Thomas Naunheim'
        $t.Renderer.Close()
    }

    It 'Reads the contributors from a file, and has no panel when the file cannot be read' {
        $file = Join-Path $TestDrive 'contributors.json'
        Set-Content -LiteralPath $file -Value '[{"Name":"Ada Lovelace","GitHub":"ada-l","Tests":2,"Improvements":0,"Since":2025}]'
        $t = New-TestPanelDashboard -Panels 'Contributor'
        $t.Renderer.LoadContributorsAsync($file, 7).Wait()
        $t.Renderer.Start(1)
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '│ Ada Lovelace +@ada-l │'
        $t.Renderer.Close()

        $none = New-TestPanelDashboard -Panels 'Contributor'
        $none.Renderer.LoadContributorsAsync((Join-Path $TestDrive 'missing.json'), 0).Wait()
        Set-Content -LiteralPath $file -Value 'not json'
        $none.Renderer.LoadContributorsAsync($file, 0).Wait()
        $none.Renderer.Start(1)
        ($none.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Not -Match 'Featured contributor'
        $none.Renderer.Close()
    }

    It 'Keeps every panel in a short column: the Slowest panel shrinks to one test' {
        $t = New-TestPanelDashboard -Panels 'Tenant', 'Failed', 'Slowest', 'Tips'
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('One', 'Two', 'Three'))
        $t.Renderer.SetTips(@('A tip'))
        $t.Renderer.Start(50)
        1..12 | ForEach-Object { $t.Renderer.ItemStarting("W.$_", "Test $_", $null); $t.Renderer.ItemFinished("W.$_", 'Failed', 'High') }
        $count = {
            param($height)
            $screen = $t.Renderer.GetPlainScreen(160, $height)
            [pscustomobject]@{
                Panels = @($screen | Where-Object { $_ -match '╭─ (Tenant|Failed so far|Slowest so far|Tip) ' }).Count
                Tests  = @($screen | Where-Object { $_ -match '│ W\.\d+ ' }).Count
            }
        }
        # 17 rows hold the four panels with the Slowest panel at its smallest: one test.
        (& $count 18).Panels | Should -Be 4
        (& $count 18).Tests | Should -Be 1
        # Each row that is left over goes to one more test.
        (& $count 19).Tests | Should -Be 2
        (& $count 22).Tests | Should -Be 5
        # One row short: the other panels take less, and the four are still there.
        (& $count 17).Panels | Should -Be 4
        (& $count 17).Tests | Should -BeGreaterOrEqual 1
        $t.Renderer.Close()
    }

    It 'Makes the other panels smaller before it leaves one out' {
        $t = New-TestPanelDashboard -Panels 'Failed', 'Tips'
        $long = 'one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one'
        $t.Renderer.SetTips(@('Short', $long))
        $t.Renderer.Start(5)
        $t.Renderer.ItemFinished('F.1', 'Failed', 'High')
        # With room: the four severities, and the Tips panel as tall as its longest tip.
        $roomy = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $roomy | Should -Match '│ Critical '
        $roomy | Should -Match '│ Short +│\n[^\n]*│ +│\n'
        # Without: only the severity that has failures, and the tip at its own height. Both panels stay.
        $tight = $t.Renderer.GetPlainScreen(160, 9)
        @($tight | Where-Object { $_ -match '╭─ (Failed so far|Tip) ' }).Count | Should -Be 2
        ($tight -join "`n") | Should -Not -Match '│ (Critical|Medium|Low) '
        ($tight -join "`n") | Should -Match '│ High '
        ($tight -join "`n") | Should -Match '│ Short +│\n[^\n]*╰'
        $t.Renderer.Close()
    }

    It 'Shows the connections in a grid, connected ones with a green dot, and cuts a name that is too long' {
        $t = New-TestPanelDashboard -Panels 'Connections'
        $t.Renderer.SetConnections(@('Graph', 'Exchange Online', 'Security & Compliance', 'Teams', 'Azure DevOps'), @($true, $true, $true, $false, $false))
        $t.Renderer.Start(1)
        $box = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box[0] | Should -Match '^╭─ Connections ─+ 3 of 5 ─╮$'
        $box[1] | Should -Match '^│ ● Graph +● Exchange Online +│$'
        $box[2] | Should -Match '^│ ● Security & Compliance +○ Teams +│$'
        $box[3] | Should -Match '^│ ○ Azure DevOps +│$'
        # The second column starts at the same place on every row.
        $box[1].IndexOf('● Exchange') | Should -Be $box[2].IndexOf('○ Teams')
        # Connected is green; not connected is dim.
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[32m●$esc[0m Graph"))
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[2m○$esc[0m $esc[2mTeams$esc[0m"))
        $t.Renderer.Close()

        $narrow = New-TestPanelDashboard -Width 142 -Panels 'Connections'
        $narrow.Renderer.SetConnections(@('Security & Compliance', 'Graph'), @($true, $true))
        $narrow.Renderer.Start(1)
        ($narrow.Renderer.GetPlainScreen(142, 44) -join "`n") | Should -Match '│ ● Security & Com… +● Graph +│'
        $narrow.Renderer.Close()
    }

    It 'Shows a service that is still being checked with a spinner, and says the count once every answer is in' {
        $t = New-TestPanelDashboard -Panels 'Connections'
        $t.Renderer.SetConnections(@('Graph', 'Azure', 'Teams'), [bool[]]@($true, $false, $false), [bool[]]@($false, $true, $true))
        $box = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box[0] | Should -Match '^╭─ Connections ─+ checking… ─╮$'
        $box[1] | Should -Match '^│ ● Graph +[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Azure +│$'
        $box[2] | Should -Match '^│ [⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Teams +│$'
        # A service that is being checked is not connected yet, whatever was said for it.
        $t.Renderer.SetConnections(@('Graph', 'Azure'), [bool[]]@($true, $true), [bool[]]@($false, $true))
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Not -Match '● Azure'
        # With every answer in, the panel is as it always was.
        $t.Renderer.SetConnections(@('Graph', 'Azure', 'Teams'), [bool[]]@($true, $true, $false), [bool[]]@($false, $false, $false))
        $box = @($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box[0] | Should -Match '^╭─ Connections ─+ 2 of 3 ─╮$'
        $box[1] | Should -Match '^│ ● Graph +● Azure +│$'
        $box[2] | Should -Match '^│ ○ Teams +│$'
        $t.Renderer.Close()
    }

    It 'Shows the Results and Failed panels at zero before the tests start, when asked to' {
        # As before: nothing until the tests start.
        $t = New-TestPanelDashboard -Panels 'Totals', 'Failed'
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Not -Match '╭─ (Results|Failed so far) '
        $t.Renderer.Close()

        $t = New-TestPanelDashboard -Panels 'Totals', 'Failed'
        $t.Renderer.PanelsBeforeStart = $true
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '╭─ Results ─+ starting… ─╮'
        $screen | Should -Match '╭─ Failed so far ─+ 0 ─╮'
        $screen | Should -Match '│ Critical +0 │'
        # Once the tests start the panels count as they always did.
        $t.Renderer.Start(4)
        $t.Renderer.ItemStarting('A.1', 'A test', $null); $t.Renderer.ItemFinished('A.1', 'Failed', 'High')
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '╭─ Results ─+ 1 of 4 ─╮'
        $screen | Should -Match '╭─ Failed so far ─+ 1 ─╮'
        $t.Renderer.Close()
    }

    It 'Writes the tagline of the banner, and mentions a newer version in it as a link' {
        $t = New-TestPanelDashboard -Panels 'Tips'
        $t.Renderer.SetHeader(@('top', 'FLAME  old tagline', 'bottom'), 30, 'Maester v3.0.0')
        $t.Renderer.SetHeaderTagline(1, 'FLAME  ', 44, 'v3.0.0', 'maester.dev', 'https://maester.dev')
        # While the run prepares, the banner is on screen.
        $t.Renderer.ShowStatus('Reading the tenant context')
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        $screen[1] | Should -Match ('^FLAME  ' + (' ' * 24) + 'v3\.0\.0 · maester\.dev\b')
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev$esc\maester.dev$esc]8;;$esc\"))

        $t.Renderer.SetHeaderUpdate('v3.1.0 available', 'https://www.powershellgallery.com/packages/Maester/3.1.0')
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        $screen[1] | Should -Match '^FLAME     v3\.0\.0 · ↑ v3\.1\.0 available · maester\.dev\b'
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[1;38;5;215m$esc]8;;https://www.powershellgallery.com/packages/Maester/3.1.0$esc\↑ v3.1.0 available$esc]8;;$esc\"))
        # There is no Version panel.
        ($screen -join "`n") | Should -Not -Match '╭─ Version'
        # Once the tests start, the one line that replaces the banner mentions it too.
        $t.Renderer.Start(1)
        $t.Renderer.GetPlainScreen(160, 44)[0] | Should -Be ' MAESTER v3.0.0 · ↑ v3.1.0 available'
        $t.Renderer.Close()
    }

    It 'Gives a test ID fifteen columns in the lists, and cuts a longer one in its middle' {
        $t = New-TestPanelDashboard -Panels 'Slowest'
        $t.Renderer.Start(10)
        $t.Renderer.ItemStarting('MT.1066', 'A short one', $null)
        $t.Renderer.ItemFinished('MT.1066', 'Passed', 'Low', 2)
        $t.Renderer.ItemStarting('CIS.M365.5.1.2.2', 'One character too long', $null)
        $t.Renderer.ItemFinished('CIS.M365.5.1.2.2', 'Failed', 'High', 3)
        $t.Renderer.ItemStarting('CISA.MS.SHAREPOINT.1.1', 'Running now', $null)
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        # The title starts in the same column on every row: three for the mark, fifteen for the ID, one space.
        ($screen | Where-Object { $_ -match 'Running now' }) | Should -Match '^ . CISA\.MS…INT\.1\.1 Running now '
        ($screen | Where-Object { $_ -match '^ ✗ ' }) | Should -Match '^ ✗ CIS\.M36…5\.1\.2\.2 One character too long '
        ($screen | Where-Object { $_ -match '^ ✓ ' }) | Should -Match '^ ✓ MT\.1066 {9}A short one '
        # The same column in the Slowest panel.
        ($screen -join "`n") | Should -Match '│ CIS\.M36…5\.1\.2\.2 One character too long +3\.0s │'
        ($screen -join "`n") | Should -Match '│ MT\.1066 {9}A short one +2\.0s │'
        $t.Renderer.Close()
    }

    It 'Fills the rows under the running tests with the tests that ran before, newest first' {
        $t = New-TestPanelDashboard -Panels 'Results'
        $t.Renderer.Start(60)
        $results = 'Passed', 'Failed', 'Error', 'Investigate', 'Skipped'
        1..40 | ForEach-Object { $t.Renderer.ItemStarting("H.$_", "Test $_", $null); $t.Renderer.ItemFinished("H.$_", $results[$_ % 5], 'High') }
        $t.Renderer.ItemStarting('H.41', 'Running now', $null)
        $screen = $t.Renderer.GetPlainScreen(160, 30)
        $running = [array]::IndexOf($screen, ($screen | Where-Object { $_ -match '^ Running' }))
        $screen[$running + 1] | Should -Match 'H\.41 +Running now'
        # Newest first, each with the mark of its result. H.39 was skipped, so it is not listed.
        $screen[$running + 2] | Should -Match '^ ✓ H\.40 +Test 40 +[\d.]+s$'
        $screen[$running + 3] | Should -Match '^ \? H\.38 '
        $screen[$running + 4] | Should -Match '^ ! H\.37 '
        $screen[$running + 5] | Should -Match '^ ✗ H\.36 '
        # The list goes down to the last row of the content.
        $screen.Count | Should -Be 29
        $screen[28] | Should -Match '^ . H\.\d+ '
        $t.Renderer.Close()
    }

    It 'Draws a status bar of links on the last row, and then leaves the site out of the tagline' {
        $t = New-TestPanelDashboard -Panels 'Results'
        $t.Renderer.SetHeader(@('top', 'FLAME  old tagline', 'bottom'), 30, 'Maester v3.0.0')
        $t.Renderer.SetHeaderTagline(1, 'FLAME  ', 44, 'v3.0.0', 'maester.dev', 'https://maester.dev')
        $t.Renderer.SetStatusBar(@('maester.dev', 'Contributors', 'Our Manifesto', '♥ Sponsor'), @('https://maester.dev', 'https://maester.dev/contributors', 'https://maester.cloud/manifesto', 'https://github.com/maester365/maester?sponsor=1'))
        $t.Renderer.ShowStatus('Reading the tenant context')
        $screen = $t.Renderer.GetPlainScreen(160, 30)
        $screen.Count | Should -Be 30
        $screen[29] | Should -Be (' maester.dev  Contributors │ Our Manifesto │ ♥ Sponsor ').PadRight(159)
        $screen[1] | Should -Match '^FLAME +v3\.0\.0$'
        $t.Renderer.Start(1)
        $out = $t.Writer.ToString()
        # Without true colour: dark text on one orange, the name in bold, each label a hyperlink.
        $out | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev$esc\$esc[1;38;5;232;48;5;208m maester.dev $esc]8;;$esc\"))
        $out | Should -Match ([regex]::Escape("$esc]8;;https://github.com/maester365/maester?sponsor=1$esc\ ♥ Sponsor $esc]8;;$esc\"))
        # With true colour: the gradient of the wordmark, Maester red at the left edge to amber at the right,
        # with white text on the red and dark text on the amber.
        $t.Renderer.TrueColor = $true
        $t.Renderer.SetStatusBar(@('maester.dev', 'Sponsor'), @('https://maester.dev', $null), 1)
        $out = $t.Writer.ToString()
        $out | Should -Match ([regex]::Escape("$esc[1;38;2;255;255;255;48;2;229;36;59m "))
        $out | Should -Match ([regex]::Escape("38;2;43;13;6;48;2;255;181;71m $esc[0m"))
        $t.Renderer.TrueColor = $false
        $t.Renderer.SetStatusBar(@('maester.dev', 'Contributors', 'Our Manifesto', '♥ Sponsor'), @($null, $null, $null, $null))
        # A narrow window keeps the labels that fit.
        $t.Renderer.GetPlainScreen(40, 30)[29] | Should -Be (' maester.dev  Contributors ').PadRight(39)

        # With a right group the bar spans the window; a narrow window drops the right group from its left.
        $t.Renderer.SetStatusBar(@('maester.dev', 'Docs', 'Issues', 'Sponsor'), @($null, $null, $null, $null), 2)
        $t.Renderer.GetPlainScreen(60, 30)[29] | Should -Be (' maester.dev  Docs ' + (' ' * 22) + ' Issues │ Sponsor ')
        $t.Renderer.GetPlainScreen(32, 30)[29] | Should -Be (' maester.dev  Docs ' + (' ' * 3) + ' Sponsor ')
        $t.Renderer.GetPlainScreen(24, 30)[29] | Should -Be (' maester.dev  Docs ').PadRight(23)

        # A hint sits in the middle of the room between the groups, and is left out when it does not fit.
        $t.Renderer.SetStatusBarHint('click me')
        $t.Renderer.GetPlainScreen(60, 30)[29] | Should -Be (' maester.dev  Docs ' + (' ' * 7) + 'click me' + (' ' * 7) + ' Issues │ Sponsor ')
        $t.Renderer.GetPlainScreen(48, 30)[29] | Should -Be (' maester.dev  Docs ' + (' ' * 10) + ' Issues │ Sponsor ')
        $t.Renderer.Close()
    }

    It 'Says how long ago the earlier run was, and when' {
        $t = New-TestPanelDashboard
        $before = [System.Collections.Generic.Dictionary[string, string]]::new()
        $before['A.1'] = 'Passed'; $before['A.2'] = 'Investigate'
        $when = (Get-Date).AddDays(-4).AddMinutes(-5)
        $t.Renderer.SetBaseline($before, $when)
        $t.Renderer.Start(2)
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '╭─ Drift since last run ─+ 4 days ago ─╮'
        $screen | Should -Match ([regex]::Escape($when.ToString('MMM d, HH:mm', [cultureinfo]::InvariantCulture)) + '  ✓ 1  ✗ 0  \? 1 ')
        # The date opens the report of that run, when its address is known.
        $date = $when.ToString('MMM d, HH:mm', [cultureinfo]::InvariantCulture)
        $t.Writer.ToString() | Should -Not -Match ([regex]::Escape("$esc]8;;file:"))
        $t.Renderer.SetBaselineReport('file:///results/TestResults-old.html')
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;file:///results/TestResults-old.html$esc\$date$esc]8;;$esc\"))
        $t.Renderer.Close()
    }

    It 'Puts an age in words' {
        $cases = [ordered]@{
            'just now' = [timespan]::FromSeconds(20); '10 min ago' = [timespan]::FromMinutes(10.9); '1 hour ago' = [timespan]::FromMinutes(61)
            '5 hours ago' = [timespan]::FromHours(5.5); '1 day ago' = [timespan]::FromHours(30); '4 days ago' = [timespan]::FromDays(4)
            '2 months ago' = [timespan]::FromDays(75); '1 year ago' = [timespan]::FromDays(400); '-' = [timespan]::FromMinutes(-5)
        }
        foreach ($case in $cases.GetEnumerator()) {
            $expected = if ($case.Key -eq '-') { 'just now' } else { $case.Key }
            [Maester.Engine.MtConsoleRenderer]::FormatAge($case.Value) | Should -Be $expected
        }
    }

    It 'Keeps the colours and the hyperlink of a line that is cut' {
        $t = New-TestPanelDashboard -Panels 'Blog'
        $link = [Maester.Engine.MtConsoleRenderer]::Hyperlink(('A long title ' * 8), 'https://maester.dev/blog/post')
        $t.Renderer.SetPanelText('Blog', 'From the blog', @("$esc[2mOct 07$esc[0m  $link", "$esc[2mJul 26$esc[0m  Short"))
        $t.Renderer.Start(1)
        $out = $t.Writer.ToString()
        # The cut line still has its dimmed date and its link, and the link is closed after the ellipsis.
        $out | Should -Match ([regex]::Escape("$esc[2mOct 07$esc[0m  $esc]8;;https://maester.dev/blog/post$esc\A long title") + '[^\r\n]*…' + [regex]::Escape("$esc[0m$esc]8;;$esc\"))
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '│ Oct 07  A long title .*… │'
        $t.Renderer.Close()
    }

    It 'Has no Drift panel without a baseline' {
        $t = New-TestPanelDashboard
        $t.Renderer.Start(1)
        $t.Renderer.ItemFinished('Passed')
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Not -Match 'Drift since last run'
        $t.Renderer.Close()
    }

    It 'Loads a baseline from a results file, and ignores a file from another tenant' {
        $file = Join-Path $TestDrive 'TestResults-old.json'
        @{ TenantId = 'tenant-a'; ExecutedAt = '2026-10-09T08:12:00'; Tests = @(@{ Id = 'A.1'; Result = 'Passed' }) } | ConvertTo-Json -Depth 4 | Set-Content $file
        $same = New-TestPanelDashboard
        $same.Renderer.LoadBaselineAsync($file, 'tenant-a', 'file:///results/old.html').Wait()
        $same.Renderer.Start(1)
        $same.Renderer.ItemFinished('A.1', 'Failed', 'High')
        ($same.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '1 newly failing'
        $same.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;file:///results/old.html$esc\"))
        $same.Renderer.Close()

        $other = New-TestPanelDashboard
        $other.Renderer.LoadBaselineAsync($file, 'tenant-b').Wait()
        $other.Renderer.LoadBaselineAsync((Join-Path $TestDrive 'missing.json'), 'tenant-a').Wait()
        $other.Renderer.Start(1)
        $other.Renderer.ItemFinished('A.1', 'Failed', 'High')
        ($other.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Not -Match 'Drift since last run'
        $other.Renderer.Close()
    }

    It 'Shows a duration in seconds under a minute and in minutes from there, lined up on the decimal point' {
        $t = New-TestRenderer -Width 100
        $t.Renderer.Height = 30
        $t.Renderer.FullScreen = $true
        $t.Renderer.Open()
        $t.Renderer.Start(10)
        $seconds = 0.42, 21.3, 59.94, 59.97, 135.2, 4500
        for ($i = 0; $i -lt $seconds.Count; $i++) {
            $t.Renderer.ItemStarting("D.$i", "Test $i", $null)
            $t.Renderer.ItemFinished("D.$i", 'Passed', 'High', $seconds[$i])
        }
        $rows = @($t.Renderer.GetPlainScreen(100, 30) | Where-Object { $_ -match '^ ✓ D\.\d ' })
        $shown = @($rows | ForEach-Object { ($_ -split ' +')[-1] })
        # Newest first.
        $shown | Should -Be @('75.0m', '2.3m', '1.0m', '59.9s', '21.3s', '0.4s')
        # One decimal and a one-letter unit: every value ends in the same column.
        @($rows | ForEach-Object { $_.TrimEnd().Length } | Sort-Object -Unique).Count | Should -Be 1
        $t.Renderer.Close()
    }

    It 'Graphs how long each test took in the main column, newest on the right, on a logarithmic scale' {
        $t = New-TestPanelDashboard -Panels 'Pace', 'Slowest'
        $t.Renderer.TrueColor = $true
        $t.Renderer.Start(20)
        $n = 0
        foreach ($seconds in 0.05, 34, 0.4, 3, 0.0) {
            $n++
            $t.Renderer.ItemStarting("S.$n", "Test $n", $null)
            $t.Renderer.ItemFinished("S.$n", 'Passed', 'Low', $seconds)
        }
        # A test that was skipped did not run: it has no bar, and is not among the slowest.
        $t.Renderer.ItemFinished('K.1', 'Skipped', 'Low', 9)
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        # The main column is the first 98 characters of a row; the panels are to its right.
        $main = @($screen | ForEach-Object { $_.PadRight(98).Substring(0, 98).TrimEnd() })
        $caption = [array]::IndexOf($main, ($main | Where-Object { $_ -match '^ how long each test took' }))
        $main[$caption] | Should -Match '^ how long each test took, newest on the right +[\d.]+ tests/s · longest 34\.0s$'
        # Five rows, forty steps of height. The 34 seconds fill them; 3 seconds reach the fourth row,
        # 0.4 seconds the second, 50 milliseconds half of the first, and the fastest test still shows.
        # The bars stand against the right edge of the column (97 characters), the newest at the very right.
        $main[$caption - 5] | Should -Be (' █'.PadLeft(94))
        $main[$caption - 4] | Should -Be (' █ ▁'.PadLeft(96))
        $main[$caption - 3] | Should -Be (' █ █'.PadLeft(96))
        $main[$caption - 2] | Should -Be (' █▅█'.PadLeft(96))
        $main[$caption - 1] | Should -Be ('▄███▁'.PadLeft(97))
        # The slowest tests have their panel in the right column.
        $box = @($screen | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box[0] | Should -Match '^╭─ Slowest so far ─+╮$'
        $box[1] | Should -Match '^│ S\.2 +Test 2 +34\.0s │$'
        $box[2] | Should -Match '^│ S\.4 +Test 4 +3\.0s │$'
        ($box -join "`n") | Should -Not -Match 'K\.1'
        # Each row of the graph has its colour: green at the bottom to red at the top.
        $out = $t.Writer.ToString()
        $out | Should -Match ([regex]::Escape("$esc[38;2;63;182;139m") + ' +▄███▁')
        $out | Should -Match ([regex]::Escape("$esc[38;2;224;108;117m") + ' +█')
        $t.Renderer.TrueColor = $false
        $t.Renderer.ItemFinished('S.6', 'Passed', 'Low', 0.1)
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[32m") + ' +▄███▁▇')
        $t.Renderer.Close()
    }

    It 'Leaves the graph out when the console is too short for it' {
        $t = New-TestPanelDashboard -Panels 'Pace', 'Results'
        $t.Renderer.Start(20)
        $t.Renderer.ItemFinished('S.1', 'Passed', 'Low', 1)
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match 'how long each test took'
        $short = $t.Renderer.GetPlainScreen(160, 12) -join "`n"
        $short | Should -Not -Match 'how long each test took'
        $short | Should -Match '■'
        $t.Renderer.Close()
    }

    It 'Shows the latest tests, the newest on the right, when more tests ran than there are columns' {
        $t = New-TestPanelDashboard -Width 100 -Panels 'Pace'
        $t.Renderer.Start(200)
        # 98 columns. Before they are full the bars stand against the right edge, one to a test.
        1..6 | ForEach-Object { $t.Renderer.ItemFinished("B.$_", 'Passed', 'Low', 30) }
        1..40 | ForEach-Object { $t.Renderer.ItemFinished("Q.$_", 'Passed', 'Low', 0) }
        $part = $t.Renderer.GetPlainScreen(100, 44) -join "`n"
        $part | Should -Match ('\n {53}' + ('█' * 6) + ('▁' * 40) + '\n how long each test took, newest on the right +[\d.]+ tests/s · longest 30\.0s\n')
        # Sixty more: the six slow tests of the start have moved out at the left, and the scale is still theirs.
        1..60 | ForEach-Object { $t.Renderer.ItemFinished("R.$_", 'Passed', 'Low', 0) }
        $full = $t.Renderer.GetPlainScreen(100, 44) -join "`n"
        $full | Should -Match ('\n ' + ('▁' * 98) + '\n how long the last 98 tests took, newest on the right +[\d.]+ tests/s · longest 30\.0s\n')
        # A slow test comes in at the right edge.
        $t.Renderer.ItemFinished('S.1', 'Passed', 'Low', 30)
        ($t.Renderer.GetPlainScreen(100, 44) -join "`n") | Should -Match ('\n ' + ('▁' * 97) + '█\n')
        $t.Renderer.Close()
    }

    It 'Wraps a tip to the width of the column' {
        $t = New-TestPanelDashboard -Width 141
        $t.Renderer.SetTips(@('one two three four five six seven eight nine ten eleven twelve thirteen fourteen'))
        $screen = $t.Renderer.GetPlainScreen(141, 44)
        ($screen | Where-Object { $_ -match '╭─ Tip ─+╮$' }) | Should -Not -BeNullOrEmpty
        # The Tip panel has the border of the other panels, not an accent.
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[38;5;240m╭─ $esc[0m$esc[1mTip"))
        foreach ($line in $screen) { $line.Length | Should -BeLessThan 141 }
        ($screen -join ' ') | Should -Match 'fourteen'
        $t.Renderer.Close()
    }
    It 'Draws each panel as a closed box of the same width' {
        $t = New-TestPanelDashboard
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso'))
        $t.Renderer.SetTips(@('A tip'))
        $t.Renderer.Start(2)
        $t.Renderer.ItemFinished('A.1', 'Failed', 'High')
        $pane = @($t.Renderer.GetPlainScreen(160, 44) | ForEach-Object { if ($_.Length -gt 101) { $_.Substring(101) } } | Where-Object { $_.Trim() })
        @($pane | Where-Object { $_ -match '^╭' }).Count | Should -Be @($pane | Where-Object { $_ -match '^╰─+╯$' }).Count
        @($pane | ForEach-Object { $_.Length } | Select-Object -Unique).Count | Should -Be 1
        foreach ($line in $pane) { $line | Should -Match '^[╭│╰].*[╮│╯]$' }
        $t.Renderer.Close()
    }

    It 'Colours the border of a panel by its state' {
        $t = New-TestPanelDashboard
        $t.Renderer.Start(2)
        $t.Renderer.ItemFinished('A.1', 'Passed', 'High')
        $before = $t.Writer.ToString().Length
        $t.Renderer.ItemFinished('A.2', 'Failed', 'High')
        $frame = $t.Writer.ToString().Substring($before)
        $frame | Should -Match ([regex]::Escape("$esc[31m╭─ "))
        $t.Renderer.Close()
    }

    It 'Draws boxes with ASCII when Unicode is off' {
        $t = New-TestPanelDashboard
        $t.Renderer.Unicode = $false
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso'))
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '\+- Tenant -+\+'
        $screen | Should -Match '\| Contoso +\|'
        $screen | Should -Not -Match '[╭╮╰╯│─]'
        $t.Renderer.Close()
    }

    It 'Marks the squares of the tests that are running' {
        $t = New-TestPanelDashboard
        $t.Renderer.Ansi = $false
        $t.Renderer.Start(10)
        1..3 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
        $t.Renderer.ItemStarting('R.1', 'Running one')
        $t.Renderer.ItemStarting('R.2', 'Running two')
        # The main column is the first 98 characters of a row; the panels are to its right.
        $chart = { ($t.Renderer.GetPlainScreen(160, 44) | Where-Object { $_ -match '[■□]' }).PadRight(98).Substring(0, 98).Trim() }
        # A running test shows a spinner like the one of the list of running tests, as tall as a square.
        & $chart | Should -Be '■■■⠲⠲□□□□□'
        $t.Renderer.ItemFinished('R.1', 'Passed')
        & $chart | Should -Be '■■■■⠲□□□□□'
        $t.Renderer.Close()
    }
}

Describe 'MtConsoleRenderer insight panels' {
    BeforeAll {
        $script:insightPanels = 'Tenant', 'Totals', 'Connections', 'Failed', 'Slowest', 'Drift', 'FixFirst', 'Blog', 'Tips', 'Contributor', 'Pace', 'Results',
        'WeakestAreas', 'AttackTactics', 'FailedTests', 'NistFamilies', 'PassRate', 'EveryTest'
        $script:insightAreas = @{ identity = 'Identity area'; devices = 'Devices and endpoints'; data = 'Data protection'; tiny = 'Tiny area' }
        # T1078.004 is not listed: a sub-technique has the tactic of its technique.
        $script:insightTactics = @{ T1078 = 'Initial Access'; T1110 = 'Credential Access' }
        $script:insightFamilies = @{ AC = 'Access Control'; IA = 'Identification and Authentication'; AU = 'Audit and Accountability'; SC = 'System and Communications Protection' }
        $script:insightFailed = 'T01', 'T02', 'T03', 'T04', 'T11', 'T12', 'T27', 'T30'

        function New-InsightTestInfo {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([string] $Id, [string] $Area, [string] $Severity = 'Medium', [string] $UserImpact, [string] $Cost, [string[]] $Mitre = @(), [string[]] $Controls = @())
            $info = [Maester.Engine.MtConsoleTestInfo]::new()
            $info.Id = $Id; $info.Area = $Area; $info.Severity = $Severity; $info.UserImpact = $UserImpact; $info.ImplementationCost = $Cost
            $info.Mitre = $Mitre; $info.Controls = $Controls
            $info
        }

        # Thirty tests in four areas. The ones in $insightFailed fail; what each panel then shows is in the tests below.
        function Get-InsightFixture {
            $set = @{
                T01 = @{ Severity = 'Critical'; UserImpact = 'Low'; Cost = 'Low'; Mitre = 'T1078', 'T1078.004'; Controls = 'nist-800-53-r5:AC-2', 'nist-800-53-r5:AC-6(5)', 'cisa-scuba:MS.AAD.3.1' }
                T02 = @{ Severity = 'High'; UserImpact = 'Low'; Cost = 'Low'; Mitre = 'T1110'; Controls = 'nist-800-53-r5:AC-3' }
                T03 = @{ Severity = 'Medium'; UserImpact = 'Low'; Cost = 'Low'; Mitre = 'T1078.004', 'T1110'; Controls = 'nist-800-53-r5:AU-6' }
                T04 = @{ Severity = 'High'; UserImpact = 'Medium'; Cost = 'High' }
                T05 = @{ Controls = 'nist-800-53-r5:AC-2' }
                T06 = @{ Controls = 'nist-800-53-r5:AC-17' }
                T11 = @{ Severity = 'High'; UserImpact = 'High'; Cost = 'Low'; Mitre = 'T1078'; Controls = 'nist-800-53-r5:IA-2' }
                T12 = @{ Severity = 'Low' }
                T13 = @{ Controls = 'nist-800-53-r5:IA-5' }
                T14 = @{ Controls = 'nist-800-53-r5:IA-5' }
                T15 = @{ Controls = 'nist-800-53-r5:IA-8' }
                T21 = @{ Controls = 'nist-800-53-r5:AU-2', 'nist-800-53-r5:SC-7' }
                T22 = @{ Controls = 'nist-800-53-r5:SC-8' }
                T23 = @{ Controls = 'nist-800-53-r5:SC-13' }
                T27 = @{ Severity = 'Critical'; UserImpact = 'Low'; Cost = 'Low' }
                T30 = @{ Severity = 'Critical' }
            }
            1..30 | ForEach-Object {
                $id = 'T{0:00}' -f $_
                $area = if ($_ -le 10) { 'identity' } elseif ($_ -le 20) { 'devices' } elseif ($_ -le 28) { 'data' } else { 'tiny' }
                $more = if ($set.ContainsKey($id)) { $set[$id] } else { @{} }
                New-InsightTestInfo -Id $id -Area $area @more
            }
        }

        function New-InsightDashboard {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param(
                [int] $Total = 30, [string[]] $Panels = $script:insightPanels, [object[]] $Tests = @(Get-InsightFixture),
                [switch] $Ascii, [switch] $NoColor,
                # The main column of a run of the whole catalog: the logo, thirteen lanes, the squares of 746 tests and three running tests.
                [switch] $Catalog
            )
            $t = New-TestRenderer -Width 165 -Ascii:$Ascii -NoColor:$NoColor
            $r = $t.Renderer
            $r.Height = 64; $r.FullScreen = $true
            $r.SetPanels($Panels)
            $r.SetPhases(@('Prepare', 'Run tests', 'Results', 'Reports'))
            $r.SetTenant('Contoso', 'contoso.example', 'admin@contoso.example')
            $r.SetConnections(@('Graph', 'Exchange'), [bool[]]@($true, $false))
            $r.SetTips(@('A tip'))
            $post = [Maester.Engine.MtBlogPost]::new(); $post.Title = 'A post'; $post.Link = 'https://maester.dev/blog/a-post'
            $r.SetBlogPost($post)
            $person = [Maester.Engine.MtContributor]::new(); $person.Name = 'Ada'; $person.GitHub = 'ada'; $person.Tests = 3
            $r.SetContributors([Maester.Engine.MtContributor[]]@($person), 0)
            $baseline = [System.Collections.Generic.Dictionary[string, string]]::new(); $baseline['T05'] = 'Passed'
            $r.SetBaseline($baseline, 'earlier')
            $r.SetStatusBar(@('maester.dev'), @('https://maester.dev'))
            $r.Open()
            $r.SetTestInfo([Maester.Engine.MtConsoleTestInfo[]]$Tests, $script:insightAreas, $script:insightTactics, $script:insightFamilies)
            if ($Catalog) {
                $r.SetRunLogo([string[]]@(1..7 | ForEach-Object { ' LOGO' }), 61, 6, ' ', 'v3')
                $r.Start(746, [string[]]@(1..13 | ForEach-Object { "Product $_" }), [int[]]@(1..13 | ForEach-Object { 50 }), $null)
            } else {
                $r.Start($Total)
            }
            $t
        }

        # Finishes the tests of the fixture in order; test n takes n tenths of a second.
        function Complete-InsightTest {
            param($Renderer, [int] $Count = 30)
            for ($i = 1; $i -le $Count; $i++) {
                $id = 'T{0:00}' -f $i
                $Renderer.ItemStarting($id, "Title of $id", $null)
                $Renderer.ItemFinished($id, $(if ($id -in $script:insightFailed) { 'Failed' } else { 'Passed' }), 'High', $i / 10)
            }
        }

        # The lines of one insight panel, without its border, by its title.
        function Get-InsightPanel {
            param([string[]] $Screen, [string] $Title)
            $top = @($Screen | Where-Object { $_ -match "[╭+][─-] $([regex]::Escape($Title)) " })[0]
            if (-not $top) { return @() }
            $row = [array]::IndexOf($Screen, $top)
            $from = $top.IndexOf($Title) - 3
            $width = ($top.Substring($from) -replace '(?<=[╮+]).*$').Length
            if ($top.Substring($from, 1) -eq '+') { $width = $top.IndexOf('+', $from + 1) - $from + 1 }
            @(1..7 | ForEach-Object { $Screen[$row + $_].Substring($from + 2, $width - 4).TrimEnd() })
        }
    }

    It 'Lists the weakest areas: enough tests and a failure, the lowest pass rate first' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $panel = Get-InsightPanel $t.Renderer.GetPlainScreen(165, 64) 'Weakest areas'
        $panel[0] | Should -Match '^Identity area +[█▏▎▍▌▋▊▉]+░+ +60% ✗  4$'
        $panel[1] | Should -Match '^Devices and endp\S*… [█▏▎▍▌▋▊▉]+░+ +80% ✗  2$' # a name that is too long for its column is cut
        $panel[2] | Should -Match '^Data protection +[█▏▎▍▌▋▊▉]+░* +88% ✗  1$'
        # Two tests are too few to say anything about an area.
        ($panel -join "`n") | Should -Not -Match 'Tiny'
        $panel[3] | Should -BeNullOrEmpty
        $t.Renderer.Close()
    }

    It 'Colours a pass rate red under 70 percent, yellow under 85 and green from there' {
        $t = New-InsightDashboard
        Complete-InsightTest $t.Renderer
        $frame = $t.Writer.ToString()
        $frame = $frame.Substring($frame.LastIndexOf("$esc[H"))
        $frame | Should -Match "$esc\[31m +60%$esc\[0m"
        $frame | Should -Match "$esc\[33m +80%$esc\[0m"
        $frame | Should -Match "$esc\[32m +88%$esc\[0m"
        $t.Renderer.Close()
    }

    It 'Counts failed tests by ATT&CK tactic, once for a tactic, the most first' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $panel = Get-InsightPanel $t.Renderer.GetPlainScreen(165, 64) 'ATT&CK tactics'
        # T01 has two techniques of Initial Access and counts once: T01, T03 and T11. Credential Access: T02 and T03.
        $panel[0] | Should -Match '^ +3 +2$'
        $panel[6] | Should -Match '^ *Initial +Creds$'
        # The bar of the first is full height, the other two thirds of it.
        $panel[1] | Should -Match '^ +█+$'
        $panel[5] | Should -Match '^ +█+ +█+$'
        $t.Renderer.Close()
    }

    It 'Places a dot for each failed test by user impact and effort, the most severe first' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $panel = Get-InsightPanel $t.Renderer.GetPlainScreen(165, 64) 'Failed tests'
        $panel[0] | Should -Match '^ +user impact'
        $panel[1] | Should -Match '^effort +Low +Med +High$'
        # Low effort: T01 and T27 (Critical), T02 (High) and T03 (Medium) with a low impact, T11 with a high one.
        $panel[2] | Should -Match '^Low +CCHM {8,}H$'
        $panel[3] | Should -BeNullOrEmpty
        $panel[4] | Should -Match '^Med$'
        # High effort, medium impact: T04. T12 and T30 have no ratings and are left out.
        $panel[6] | Should -Match '^High +H$'
        # Six dots, and the capitals of Low, Med and High.
        (($panel[2..6] -join '') -creplace '[^CHML]').Length | Should -Be 9
        $t.Renderer.Close()

        # In colour every test is a dot in the colour of its severity.
        $t = New-InsightDashboard
        Complete-InsightTest $t.Renderer
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match "$esc\[31m●●$esc\[0m$esc\[38;5;208m●$esc\[0m$esc\[33m●$esc\[0m"
        $t.Renderer.Close()
    }

    It 'Ends a cell that has more failed tests than room with their number' {
        $tests = 1..40 | ForEach-Object { New-InsightTestInfo -Id ('T{0:00}' -f $_) -Area 'identity' -Severity 'High' -UserImpact 'Low' -Cost 'Low' }
        $t = New-InsightDashboard -NoColor -Tests $tests -Total 40
        $script:insightFailed = 1..40 | ForEach-Object { 'T{0:00}' -f $_ }
        try { Complete-InsightTest $t.Renderer -Count 40 } finally { $script:insightFailed = 'T01', 'T02', 'T03', 'T04', 'T11', 'T12', 'T27', 'T30' }
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        $panel = Get-InsightPanel $screen 'Failed tests'
        $panel[2] | Should -Match '^Low +H+$'
        $panel[3] | Should -Match '^ +H+\+\d+$'
        # The dots that are drawn and the number add up to the forty tests.
        $drawn = (($panel[2] -replace '^Low') + $panel[3] -replace '[^H]').Length
        $drawn + [int]($panel[3] -replace '^.*\+') | Should -Be 40

        # Fix first: six of the forty quick wins, and how many more there are.
        ($screen -join "`n") | Should -Match 'Fix first ─+ 40 quick wins ─'
        @($screen | Where-Object { $_ -match '│ ✗ T\d\d ' }).Count | Should -Be 6
        ($screen -join "`n") | Should -Match '│   and 34 more +│'
        $t.Renderer.Close()
    }

    It 'Lists the NIST 800-53 families by pass rate: a test counts once for a family' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $panel = Get-InsightPanel $t.Renderer.GetPlainScreen(165, 64) 'NIST 800-53 families'
        # T01 has two controls of AC and counts once: T01 and T02 failed, T05 and T06 passed.
        $panel[0] | Should -Match '^AC Access Control +[█▏▎▍▌▋▊▉]+░+ +50% ✗  2$'
        $panel[1] | Should -Match '^IA Identification.* +[█▏▎▍▌▋▊▉]+░+ +75% ✗  1$'
        # AU has two tests, which is too few, and SC has no failure. A control of another framework is not counted.
        $panel[2] | Should -BeNullOrEmpty
        $t.Renderer.Close()
    }

    It 'Draws the pass rate from the first test to now, from the lowest rate after twenty tests to 100 percent' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        # 22 of 30 passed.
        ($screen -join "`n") | Should -Match 'Pass rate so far ─+ 73% ─'
        $panel = Get-InsightPanel $screen 'Pass rate so far'
        $panel[0] | Should -Match '^100%'
        # After 21 tests 15 had passed: 71 percent, the lowest from there on.
        $panel[5] | Should -Match '^ 71% '
        $panel[6] | Should -Match '^ +first test +now$'
        # One point in each column of the chart.
        (($panel[0..5] -join '') -replace '[^▀▄]').Length | Should -Be ($panel[6].Length - 5)
        # The first tests failed: the line starts at the bottom of the scale, and ends a level above it.
        $panel[5] | Should -Match '^ 71% ▄.*▀$'
        $t.Renderer.Close()
    }

    It 'Plots every test by the order it finished in and how long it took' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $panel = Get-InsightPanel $t.Renderer.GetPlainScreen(165, 64) 'Every test'
        $panel[0] | Should -Match '^ 3\.0s '
        $panel[5] | Should -Match '^ 0\.0s'
        $panel[6] | Should -Match '^ +first test +now$'
        # Thirty tests, a braille dot each: the fastest at the bottom left, the slowest at the top right.
        $dots = 0
        foreach ($c in ($panel[0..5] -join '').ToCharArray()) {
            if ($c -ge [char]0x2801 -and $c -le [char]0x28FF) { $bits = [int]$c - 0x2800; while ($bits) { $dots += $bits -band 1; $bits = $bits -shr 1 } }
        }
        $dots | Should -Be 30
        $panel[0] | Should -Match '^ 3\.0s {5,}[⠁-⣿]+$'
        $panel[4] | Should -Match '^ {6}[⠁-⣿]'
        $t.Renderer.Close()

        # A cell with a failed test in it is red.
        $t = New-InsightDashboard
        Complete-InsightTest $t.Renderer
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match "$esc\[31m[⠁-⣿]"
        $t.Renderer.Close()
    }

    It 'Lists the quick wins in Fix first: Critical or High with a low user impact and a low cost, Critical first' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        ($screen -join "`n") | Should -Match 'Fix first ─+ 3 quick wins ─'
        $wins = @($screen | Where-Object { $_ -match '│ ✗ (T\d\d) ' } | ForEach-Object { $Matches[1] })
        # T03 is Medium, T04 and T11 are not cheap, T30 has no ratings.
        $wins | Should -Be 'T01', 'T27', 'T02'
        ($screen -join "`n") | Should -Match '│ High or Critical · low user impact · low cost +│'
        ($screen -join "`n") | Should -Match '│ ✗ T27 +Title of T27 +│'
        $t.Renderer.Close()
    }

    It 'Has no insight panels, and counts nothing, for a run of fewer than 25 tests' {
        $t = New-InsightDashboard -NoColor -Total 24
        Complete-InsightTest $t.Renderer -Count 24
        $screen = $t.Renderer.GetPlainScreen(165, 64) -join "`n"
        $screen | Should -Not -Match 'Weakest areas|ATT&CK tactics|Failed tests|NIST 800-53|Pass rate so far|Every test|Fix first'
        # The list of the tests that ran has the rows, as before.
        @($t.Renderer.GetPlainScreen(165, 64) | Where-Object { $_ -match '^ [✓✗] T\d\d ' }).Count | Should -Be 24
        $t.Renderer.Close()

        # 25 tests is a run with insight panels.
        $t = New-InsightDashboard -NoColor -Total 25
        Complete-InsightTest $t.Renderer -Count 25
        ($t.Renderer.GetPlainScreen(165, 64) -join "`n") | Should -Match 'Weakest areas'
        $t.Renderer.Close()
    }

    It 'Has none without the attributes of the tests, and counts a test it does not know for the pass rate only' {
        $t = New-InsightDashboard -NoColor -Tests @()
        Complete-InsightTest $t.Renderer
        ($t.Renderer.GetPlainScreen(165, 64) -join "`n") | Should -Not -Match 'Weakest areas|Pass rate so far|Fix first'
        $t.Renderer.Close()

        # A Pester test has no attributes: it is in the pass rate and the timings, and in no other panel.
        $t = New-InsightDashboard -NoColor -Tests @(Get-InsightFixture | Where-Object { $_.Id -ne 'T01' })
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        ($screen -join "`n") | Should -Match 'Pass rate so far ─+ 73% ─'
        (Get-InsightPanel $screen 'Weakest areas')[0] | Should -Match '^Identity area .* 67% ✗  3$'
        ($screen -join "`n") | Should -Match 'Fix first ─+ 2 quick wins ─'
        $t.Renderer.Close()
    }

    It 'Leaves a panel out while it has nothing to show, and updates the panels when a test finishes' {
        $t = New-InsightDashboard -NoColor
        # Four failed tests: their area has too few tests to be listed, and so has every control family.
        Complete-InsightTest $t.Renderer -Count 4
        $screen = $t.Renderer.GetPlainScreen(165, 64) -join "`n"
        $screen | Should -Match 'ATT&CK tactics'
        $screen | Should -Match 'Failed tests'
        $screen | Should -Match 'Pass rate so far ─+ 0% ─'
        $screen | Should -Not -Match 'Weakest areas|NIST 800-53 families'
        # The fifth test of the area: the panels are built again.
        $t.Renderer.ItemStarting('T05', 'Title of T05', $null); $t.Renderer.ItemFinished('T05', 'Passed', 'High', 1)
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        (Get-InsightPanel $screen 'Weakest areas')[0] | Should -Match '^Identity area .* 20% ✗  4$'
        ($screen -join "`n") | Should -Match 'Pass rate so far ─+ 20% ─'
        $t.Renderer.Close()

        # Before any test failed there is only the pass rate and the timings.
        $t = New-InsightDashboard -NoColor -Tests @(Get-InsightFixture | Where-Object { $_.Id -ge 'T05' })
        $t.Renderer.ItemStarting('T05', 'Title', $null); $t.Renderer.ItemFinished('T05', 'Passed', 'High', 1)
        $screen = $t.Renderer.GetPlainScreen(165, 64) -join "`n"
        $screen | Should -Match 'Pass rate so far ─+ 100% ─'
        $screen | Should -Match 'Every test'
        $screen | Should -Not -Match 'Weakest areas|ATT&CK tactics|Failed tests|Fix first'
        $t.Renderer.Close()
    }

    It 'Shows one row of panels at 165x52, both at 165x64 and none at 120x32, and leaves the list three tests' {
        $t = New-InsightDashboard -NoColor -Catalog
        Complete-InsightTest $t.Renderer
        31..33 | ForEach-Object { $t.Renderer.ItemStarting("R$_", "Running $_", $null) }
        $recent = { param($screen) @($screen | Where-Object { $_ -match '^ [✓✗] T\d\d ' }).Count }

        $screen = $t.Renderer.GetPlainScreen(165, 52)
        $row = @($screen | Where-Object { $_ -match 'Weakest areas' })
        $row.Count | Should -Be 1
        # Three panels side by side, in the main column: the right column starts after them.
        $row[0] | Should -Match '^ ╭─ Weakest areas ─.*╮ ╭─ ATT&CK tactics ─.*╮ ╭─ Failed tests ─+╮ +[│╭╰]'
        $row[0].IndexOf('╮ ╭─ ATT') | Should -BeGreaterThan 36
        ($screen -join "`n") | Should -Not -Match 'NIST 800-53 families|Pass rate so far|Every test'
        & $recent $screen | Should -Be 3
        # The panels are at the bottom of the main column, above the status bar.
        $screen[50] | Should -Match '^ ╰─+╯ ╰─+╯ ╰─+╯ '
        $screen[51] | Should -Match '^ maester\.dev'

        $screen = $t.Renderer.GetPlainScreen(165, 64)
        $first = [array]::IndexOf($screen, @($screen | Where-Object { $_ -match 'Weakest areas' })[0])
        $second = [array]::IndexOf($screen, @($screen | Where-Object { $_ -match 'NIST 800-53 families' })[0])
        $second | Should -Be ($first + 9)
        $screen[$second] | Should -Match '^ ╭─ NIST 800-53 families ─.*╮ ╭─ Pass rate so far ─.*╮ ╭─ Every test ─'
        $screen[62] | Should -Match '^ ╰─+╯ ╰─+╯ ╰─+╯ '
        # The rows that the two rows of panels leave go to more of the tests that ran.
        & $recent $screen | Should -BeGreaterThan 3

        # The lanes and the squares use a console of 32 rows: no panels, and the list is as it was.
        $screen = $t.Renderer.GetPlainScreen(120, 32)
        ($screen -join "`n") | Should -Not -Match 'Weakest areas|NIST 800-53 families|Fix first'
        $screen.Count | Should -Be 32
        $t.Renderer.Close()
    }

    It 'Shows fewer panels in a row on a console that is too narrow for three' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(80, 64)
        @($screen | Where-Object { $_ -match '^ ╭─ Weakest areas ─.*╮ ╭─ ATT&CK tactics ─+╮$' }).Count | Should -Be 1
        @($screen | Where-Object { $_ -match '^ ╭─ NIST 800-53 families ─.*╮ ╭─ Pass rate so far ─.*╮$' }).Count | Should -Be 1
        ($screen -join "`n") | Should -Not -Match 'Failed tests|Every test'
        $screen | ForEach-Object { $_.Length | Should -BeLessThan 80 }
        # A wider one has all three, each within the main column.
        $screen = $t.Renderer.GetPlainScreen(100, 64)
        @($screen | Where-Object { $_ -match 'Weakest areas.*ATT&CK tactics.*Failed tests' }).Count | Should -Be 1
        $screen | ForEach-Object { $_.Length | Should -BeLessThan 100 }
        $t.Renderer.Close()
    }

    It 'Turns a panel off when it is not in the list of panels' {
        $t = New-InsightDashboard -NoColor -Panels @($script:insightPanels | Where-Object { $_ -notin 'AttackTactics', 'FixFirst', 'EveryTest' })
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        @($screen | Where-Object { $_ -match '^ ╭─ Weakest areas ─.*╮ ╭─ Failed tests ─' }).Count | Should -Be 1
        @($screen | Where-Object { $_ -match '^ ╭─ NIST 800-53 families ─.*╮ ╭─ Pass rate so far ─' }).Count | Should -Be 1
        ($screen -join "`n") | Should -Not -Match 'ATT&CK tactics|Fix first|Every test'
        $t.Renderer.Close()
    }

    It 'Orders the right column: Slowest above Drift, Fix first under it, and blog, tip and contributor at the bottom' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        $titles = @($screen | ForEach-Object { if ($_ -match '   ╭─ ([A-Z][A-Za-z ]+?) ─') { $Matches[1] } })
        $titles | Should -Be 'Tenant', 'Results', 'Connections', 'Failed so far', 'Slowest so far', 'Drift since last run', 'Fix first', 'From the blog', 'Tip', 'Featured contributor'
        # The last three end on the last row above the status bar.
        $screen[62] | Should -Match '╰─+╯$'
        $screen[61] | Should -Match '│ 3 tests +│$'
        $blog = [array]::IndexOf($screen, @($screen | Where-Object { $_ -match '╭─ From the blog ' })[0])
        # Slowest takes the rows that are left over between the panels of the top and of the bottom.
        @($screen | Where-Object { $_ -match '│ T\d\d +Title of T\d\d +\d\.\ds │$' }).Count | Should -BeGreaterThan 5
        $fix = [array]::IndexOf($screen, @($screen | Where-Object { $_ -match '╭─ Fix first ' })[0])
        @($screen[$fix..$blog] | Where-Object { $_.Length -lt 105 }).Count | Should -Be 0
        $t.Renderer.Close()

        # They are at the bottom wherever they are in the list of panels.
        $t = New-InsightDashboard -NoColor -Panels 'Tips', 'Contributor', 'Tenant', 'Failed'
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 40)
        $titles = @($screen | ForEach-Object { if ($_ -match '   ╭─ ([A-Z][A-Za-z ]+?) ─') { $Matches[1] } })
        $titles | Should -Be 'Tenant', 'Failed so far', 'Tip', 'Featured contributor'
        $screen[38] | Should -Match '╰─+╯$'
        $t.Renderer.Close()
    }

    It 'Drops Fix first before anything else in a short column, then shrinks Slowest' {
        $t = New-InsightDashboard -NoColor
        Complete-InsightTest $t.Renderer
        $states = foreach ($height in 64..24) {
            $screen = $t.Renderer.GetPlainScreen(165, $height)
            [pscustomobject]@{
                Height  = $height
                Fix     = @($screen | Where-Object { $_ -match '│ ✗ T\d\d ' }).Count
                Slowest = @($screen | Where-Object { $_ -match '│ T\d\d +Title of T\d\d +\d\.\ds │$' }).Count
                Others  = @($screen | Where-Object { $_ -match '╭─ (Tenant|Results|Connections|Failed so far|Drift since last run|From the blog|Tip|Featured contributor) ' }).Count
            }
        }
        # Fix first has fewer tests, then none, while Slowest still has its two.
        @($states | Where-Object { $_.Fix -in 1, 2 -and $_.Slowest -eq 2 }).Count | Should -BeGreaterThan 0
        @($states | Where-Object { $_.Fix -eq 0 -and $_.Slowest -eq 2 }).Count | Should -BeGreaterThan 0
        @($states | Where-Object { $_.Fix -gt 0 -and $_.Slowest -lt 2 }).Count | Should -Be 0
        # Slowest then gives a row, down to one test, before another panel is left out.
        @($states | Where-Object { $_.Slowest -eq 1 -and $_.Others -eq 8 }).Count | Should -BeGreaterThan 0
        @($states | Where-Object { $_.Others -lt 8 -and $_.Slowest -gt 1 }).Count | Should -Be 0
        # The three of the bottom are the last to go.
        @($states | Where-Object { $_.Height -ge 30 } | ForEach-Object { @($t.Renderer.GetPlainScreen(165, $_.Height) | Where-Object { $_ -match '╭─ (From the blog|Tip|Featured contributor) ' }).Count } | Select-Object -Unique) | Should -Be 3
        $t.Renderer.Close()
    }

    It 'Keeps the insight panels when many tests run at once, and says how many more are running' {
        $t = New-InsightDashboard -NoColor -Catalog
        Complete-InsightTest $t.Renderer
        1..20 | ForEach-Object { $t.Renderer.ItemStarting("R.$_", "Running $_", 'Product 1') }
        foreach ($height in 52, 64) {
            $screen = $t.Renderer.GetPlainScreen(165, $height)
            ($screen -join "`n") | Should -Match '╭─ Weakest areas '
            ($screen -join "`n") | Should -Match 'Running · 20 tests'
            $listed = @($screen | Where-Object { $_ -match '^ \S R\.\d+ ' }).Count
            $listed | Should -BeGreaterThan 2
            $listed | Should -BeLessThan 20
            ($screen -join "`n") | Should -Match "… and $(20 - $listed) more running"
            # The tests that ran last keep their three rows.
            @($screen | Where-Object { $_ -match '^ [✓✗] T\d\d ' }).Count | Should -BeGreaterThan 2
        }
        # A taller console has both rows of panels.
        ($t.Renderer.GetPlainScreen(165, 64) -join "`n") | Should -Match '╭─ NIST 800-53 families '
        # A console of 44 rows keeps one row of panels, without the tests that ran last.
        $short = $t.Renderer.GetPlainScreen(165, 44)
        ($short -join "`n") | Should -Match '╭─ Weakest areas '
        @($short | Where-Object { $_ -match '^ \S R\.\d+ ' }).Count | Should -BeGreaterThan 0
        ($short -join "`n") | Should -Match '… and \d+ more running'
        $t.Renderer.Close()
    }

    It 'Shows the Sponsor panel as one linked line under the Contributor panel' {
        $t = New-InsightDashboard -NoColor -Panels 'Sponsor', 'Tenant', 'Contributor', 'Tips'
        $t.Renderer.SetSponsor('Sponsor us to keep building Maester', 'https://github.com/maester365/maester?sponsor=1')
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 40)
        $titles = @($screen | ForEach-Object { if ($_ -match '   ╭─ ([A-Z][A-Za-z ]+?) ─') { $Matches[1] } })
        $titles | Should -Be 'Tenant', 'Featured contributor', 'Tip', 'Sponsor'
        $screen[37] | Should -Match '│ ♥  Sponsor us to keep building Maester +│$'
        $screen[38] | Should -Match '╰─+╯$'
        $t.Renderer.Close()

        # The line is a hyperlink to the sponsor page.
        $c = New-InsightDashboard -Panels 'Sponsor'
        $c.Renderer.SetSponsor('Sponsor us to keep building Maester', 'https://github.com/maester365/maester?sponsor=1')
        $c.Writer.GetStringBuilder().Clear() > $null
        $c.Renderer.ShowStatus($null)
        $c.Writer.ToString() | Should -Match ([regex]::Escape("]8;;https://github.com/maester365/maester?sponsor=1"))
        $c.Renderer.Close()

        # Without a text there is no panel.
        $none = New-InsightDashboard -NoColor -Panels 'Sponsor', 'Tenant'
        ($none.Renderer.GetPlainScreen(165, 40) -join "`n") | Should -Not -Match '╭─ Sponsor '
        $none.Renderer.Close()
    }

    It 'Lists the lanes whose tests were all skipped on one line' {
        $t = New-TestRenderer -Width 120 -NoColor
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true
        $r.Open()
        $r.Start(9, [string[]]@('Entra ID', 'Azure', 'GitHub'), [int[]]@(4, 3, 2), $null)
        1..3 | ForEach-Object { $r.ItemStarting("A.$_", 'An Azure test', 'Azure'); $r.ItemFinished("A.$_", 'Skipped', 'High') }
        $r.ItemStarting('G.1', 'A GitHub test', 'GitHub'); $r.ItemFinished('G.1', 'Skipped', 'High')
        $r.ItemStarting('E.1', 'An Entra test', 'Entra ID'); $r.ItemFinished('E.1', 'Skipped', 'High')
        $screen = $r.GetPlainScreen(120, 40)
        # Azure is all skipped; GitHub and Entra ID still have tests to run, so they keep their rows.
        @($screen | Where-Object { $_ -match '^ Azure ' }).Count | Should -Be 0
        @($screen | Where-Object { $_ -match '^ (Entra ID|GitHub) ' }).Count | Should -Be 2
        @($screen | Where-Object { $_ -match '^ – Skipped  Azure \(3\)\s*$' }).Count | Should -Be 1
        $r.ItemStarting('G.2', 'A GitHub test', 'GitHub'); $r.ItemFinished('G.2', 'Skipped', 'High')
        $screen = $r.GetPlainScreen(120, 40)
        @($screen | Where-Object { $_ -match '^ GitHub ' }).Count | Should -Be 0
        @($screen | Where-Object { $_ -match '^ – Skipped  Azure \(3\) · GitHub \(2\)\s*$' }).Count | Should -Be 1
        $r.Close()

        # A product that is not connected has no tests in the run, and a note with the number skipped.
        $t = New-TestRenderer -Width 120 -NoColor
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true
        $r.Open()
        $r.Start(4, [string[]]@('Entra ID', 'Teams', 'Purview', 'Intune'), [int[]]@(4, 0, 0, 0), [string[]]@('', '12 skipped', '6 skipped', 'not licensed'))
        $screen = $r.GetPlainScreen(120, 40)
        @($screen | Where-Object { $_ -match '^ (Teams|Purview) ' }).Count | Should -Be 0
        @($screen | Where-Object { $_ -match '^ Intune .* not licensed' }).Count | Should -Be 1
        @($screen | Where-Object { $_ -match '^ – Skipped  Teams \(12\) · Purview \(6\)\s*$' }).Count | Should -Be 1
        $r.Close()
    }

    It 'Draws every panel with ASCII when Unicode is off' {
        $t = New-InsightDashboard -Ascii -NoColor
        Complete-InsightTest $t.Renderer
        $screen = $t.Renderer.GetPlainScreen(165, 64)
        $screen | ForEach-Object { $_ | Should -Match '^[\x20-\x7E]*$' }
        (Get-InsightPanel $screen 'Weakest areas')[0] | Should -Match '^Identity area +#+-+ +60% x  4$'
        (Get-InsightPanel $screen 'NIST 800-53 families')[0] | Should -Match '^AC Access Control +#+-+ +50% x  2$'
        $tactics = Get-InsightPanel $screen 'ATT&CK tactics'
        $tactics[0] | Should -Match '^ +3 +2$'
        $tactics[5] | Should -Match '^ +#+ +#+$'
        (Get-InsightPanel $screen 'Failed tests')[2] | Should -Match '^Low +CCHM +H$'
        ((Get-InsightPanel $screen 'Pass rate so far')[0..5] -join '') | Should -Match '[-_]'
        # A cell of the timings is one character: an x where a test failed, a dot where one passed.
        $every = (Get-InsightPanel $screen 'Every test')[0..5] -join ''
        $every | Should -Match 'x'
        $every | Should -Match '\.'
        ($screen -join "`n") | Should -Match '\| x T01 +Title of T01 +\|'
        ($screen -join "`n") | Should -Match '\| High or Critical, low user impact, low cost +\|'
        $t.Renderer.Close()

        # With colour and no Unicode a failed test is a star in the colour of its severity.
        $t = New-InsightDashboard -Ascii
        Complete-InsightTest $t.Renderer
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match "$esc\[31m\*\*$esc\[0m"
        $t.Renderer.Close()
    }

    It 'Never throws for attributes it cannot use' {
        $odd = @(
            (New-InsightTestInfo -Id 'T01' -Area $null -Severity 'Nonsense' -UserImpact 'Huge' -Cost $null -Mitre @($null, '', 'T9999', 'None') -Controls @($null, 'nist-800-53-r5:', 'nist-800-53-r5:12-3', 'nist-800-53-r5:ACCESS-1', 'AC-2')),
            $null,
            (New-InsightTestInfo -Id $null -Area 'identity')
        )
        $t = New-InsightDashboard -NoColor -Tests $odd
        { Complete-InsightTest $t.Renderer } | Should -Not -Throw
        { $t.Renderer.SetTestInfo($null, $null, $null, $null) } | Should -Not -Throw
        { $t.Renderer.SetTestInfo([Maester.Engine.MtConsoleTestInfo[]]@(Get-InsightFixture), $null, $null, $null) } | Should -Not -Throw
        ($t.Renderer.GetPlainScreen(165, 64) -join "`n") | Should -Match 'Results'
        $t.Renderer.Close()
    }
}

Describe 'MtConsoleFeeds' {
    It 'Reads the newest posts of an RSS feed' {
        $xml = '<?xml version="1.0"?><rss version="2.0"><channel><title>Blog</title>' +
            '<item><title><![CDATA[First post 🚀]]></title><link>https://maester.dev/blog/first</link><pubDate>Wed, 07 Oct 2026 00:00:00 GMT</pubDate></item>' +
            '<item><title>Second post</title><link>javascript:alert(1)</link><pubDate>Tue, 06 Oct 2026 00:00:00 GMT</pubDate></item>' +
            '<item><title>Third&#x9;&#xA;post</title></item><item><title>Fourth post</title></item></channel></rss>'
        $posts = [Maester.Engine.MtConsoleFeeds]::ParseFeed($xml, 3)
        $posts.Count | Should -Be 3
        $posts[0].Published | Should -Be 'Oct 07'
        $posts[0].Title | Should -Be 'First post'
        $posts[0].Link | Should -Be 'https://maester.dev/blog/first'
        $posts[1].Title | Should -Be 'Second post'
        # A link that is not a web address is dropped, control characters cannot reach the console, and an
        # emoji (whose width terminals do not agree on) is left out.
        $posts[1].Link | Should -BeNullOrEmpty
        $posts[2].Title | Should -Be 'Third post'
        $posts[2].Published | Should -BeNullOrEmpty
    }

    It 'Reads the latest version from a PowerShell Gallery response' {
        $xml = '<feed xmlns="http://www.w3.org/2005/Atom" xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">' +
            '<entry><m:properties><d:Version>2.3.0</d:Version></m:properties></entry></feed>'
        [Maester.Engine.MtConsoleFeeds]::ParseGalleryVersion($xml) | Should -Be ([version]'2.3.0')
        [Maester.Engine.MtConsoleFeeds]::ParseGalleryVersion('<feed xmlns="http://www.w3.org/2005/Atom" />') | Should -BeNullOrEmpty
    }
}

Describe 'MtConsoleRenderer and text it does not control' {
    BeforeAll {
        $script:bel = [char]7
        # A window title change, a clipboard write, leaving the alternate screen, and clearing the screen.
        $script:attacks = @("$esc]0;PWNED$bel", "$esc]52;c;AAAA$bel", "$esc[?1049l", "$esc[2J", "$([char]0x9B)2J")

        function New-FullScreenRenderer {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([string[]] $Panels = @('Tenant', 'Connections', 'Tips', 'Drift', 'Pace'))
            $t = New-TestRenderer -Width 160
            $t.Renderer.Height = 44
            $t.Renderer.FullScreen = $true
            $t.Renderer.SetPanels($Panels)
            $t.Renderer.SetPhases(@('Prepare', 'Run tests'))
            $t.Renderer.Open()
            $t
        }

        function Test-NoAttack {
            param([string] $Output)
            foreach ($attack in $script:attacks) { $Output.Contains($attack) | Should -BeFalse -Because "the sequence $($attack -replace '[^\x20-\x7E]', '?') must not reach the terminal" }
        }
    }

    It 'Takes escape sequences and line breaks out of test IDs, titles and product names' {
        $t = New-FullScreenRenderer
        $evil = $script:attacks -join 'x'
        $t.Renderer.Start(2, @("Entra$evil"), @(2), @("note$evil"))
        $t.Renderer.ItemStarting("ID.1$evil", "Title one$evil`r`nsecond line`tand a tab", "Entra$evil")
        $t.Renderer.ItemFinished("ID.1$evil", 'Failed', 'High')
        $out = $t.Writer.ToString()
        Test-NoAttack $out
        $out.Contains("one`r`nsecond") | Should -BeFalse
        # The text itself is still shown, and the finished test was matched to the one that started.
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match 'Title one'
        $screen | Should -Match '1/2'
        $t.Renderer.Close()
    }

    It 'Takes them out of the tenant, the connections, the status, the tips and the phases' {
        $t = New-FullScreenRenderer
        $evil = $script:attacks -join ''
        $t.Renderer.SetTenant("Contoso$evil", "contoso.com$evil", "admin@contoso.com$evil")
        $t.Renderer.SetConnections(@("Graph$evil"), @($true))
        $t.Renderer.SetTips(@("A tip$evil"))
        $t.Renderer.SetPhases(@("Prepare$evil", 'Run tests'))
        $t.Renderer.ShowStatus("Reading$evil")
        $t.Renderer.SetStatusBar(@("Docs$evil"), @('https://maester.dev/docs'))
        $t.Renderer.SetStatusBarHint("click$evil")
        $t.Renderer.Start(1)
        Test-NoAttack $t.Writer.ToString()
        ($t.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match 'Contoso'
        $t.Renderer.Close()
    }

    It 'Drops characters that reorder or hide text' {
        $t = New-FullScreenRenderer
        $t.Renderer.Start(1)
        $t.Renderer.ItemStarting('ID.2', "safe$([char]0x202E)txt.exe$([char]0x200B)", $null)
        $out = $t.Writer.ToString()
        $out.Contains([string][char]0x202E) | Should -BeFalse
        $out.Contains([string][char]0x200B) | Should -BeFalse
        $t.Renderer.Close()
    }

    It 'Keeps colours and safe hyperlinks in text that Maester formatted, and nothing else' {
        $t = New-FullScreenRenderer -Panels 'Blog'
        $good = [Maester.Engine.MtConsoleRenderer]::Hyperlink('post', 'https://maester.dev/blog/post')
        $bad = "$esc]8;;javascript:alert(1)$esc\click$esc]8;;$esc\"
        $t.Renderer.SetPanelText('Blog', 'From the blog', @("$esc[2mOct 07$esc[0m $good $bad $($script:attacks -join '')"))
        $t.Renderer.SetInfo(" Contoso$($script:attacks[0]) $esc[2mGraph$esc[0m", 14)
        $t.Renderer.Start(1)
        $out = $t.Writer.ToString()
        Test-NoAttack $out
        $out | Should -Match ([regex]::Escape("$esc[2mOct 07$esc[0m"))
        $out | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/blog/post"))
        $out | Should -Not -Match 'javascript:'
        $t.Renderer.Close()
    }

    It 'Makes a hyperlink only for an https or file address without control characters' {
        $h = { param($url) [Maester.Engine.MtConsoleRenderer]::Hyperlink('text', $url) }
        (& $h 'https://maester.dev/docs') | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/docs"))
        (& $h ([System.Uri]::new((Join-Path $TestDrive 'report.html')).AbsoluteUri)) | Should -Match ([regex]::Escape("$esc]8;;file://"))
        (& $h 'javascript:alert(1)') | Should -Be 'text'
        (& $h 'http://maester.dev') | Should -Be 'text'
        (& $h "https://maester.dev/$esc\$esc]0;x$([char]7)") | Should -Be 'text'
        (& $h 'not a url') | Should -Be 'text'
    }

    It 'Never shows more than 100 percent' {
        $t = New-TestRenderer -Taskbar
        $t.Renderer.Start(2)
        1..5 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
        $t.Writer.ToString() | Should -Not -Match '9;4;1;(1[0-9][1-9]|[2-9][0-9][0-9])'
        ($t.Renderer.GetPlainFrame(100) -join "`n") | Should -Match '100%'
        ($t.Renderer.GetPlainFrame(100) -join "`n") | Should -Not -Match '250%'
        $t.Renderer.Close()
    }
}

Describe 'MtConsoleRenderer and a console that fails' {
    BeforeAll {
        if (-not ('MtTestFailingWriter' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.IO;
public sealed class MtTestFailingWriter : StringWriter
{
    public bool Fail;
    public int Failures;
    public override void Write(string value)
    {
        if (Fail) { Failures++; throw new IOException("The console is gone."); }
        base.Write(value);
    }
}
'@
        }
    }

    It 'Does not throw into the run when a frame cannot be written, and restores the screen when writing works again' {
        $writer = [MtTestFailingWriter]::new()
        $renderer = [Maester.Engine.MtConsoleRenderer]::new($writer)
        $renderer.Width = 120; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
        $renderer.Open()
        $renderer.Start(2)
        $writer.Fail = $true
        { $renderer.ItemStarting('ID.1', 'Title', $null); $renderer.ItemFinished('ID.1', 'Passed', 'Low'); $renderer.Stop() } | Should -Not -Throw
        $writer.Failures | Should -BeGreaterThan 0
        $writer.Fail = $false
        { $renderer.Close() } | Should -Not -Throw
        $renderer.IsFullScreen | Should -BeFalse
        $out = $writer.ToString()
        # The cursor is shown again, auto-wrap is back on and the alternate screen is left.
        $out | Should -Match ([regex]::Escape("$esc[?25h"))
        $out | Should -Match ([regex]::Escape("$esc[?7h"))
        $out.TrimEnd().EndsWith("$esc[?1049l") | Should -BeTrue
    }

    It 'Closes without throwing when the console fails during shutdown' {
        $writer = [MtTestFailingWriter]::new()
        $renderer = [Maester.Engine.MtConsoleRenderer]::new($writer)
        $renderer.Width = 120; $renderer.Height = 40; $renderer.RefreshIntervalMs = 0; $renderer.FullScreen = $true
        $renderer.Open()
        $renderer.Start(1)
        $writer.Fail = $true
        { $renderer.Close() } | Should -Not -Throw
        $renderer.IsFullScreen | Should -BeFalse
    }
}

Describe 'MtConsoleRenderer keys, and the game behind the dashboard' {
    BeforeAll {
        # A dashboard that runs tests, with no timer: keys are handed over with SendKey and the time of the
        # game is moved on with AdvanceGame. The dice of the game are the same for every test, and unless
        # -Extras is given they add nothing to the course: only the results of the run are on it. Unless
        # -Opening is given the game is on screen at once, without the wall that breaks and the words after it.
        $script:gameBotSecond = -1
        function New-GameDashboard {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([int] $Width = 80, [int] $Height = 24, [int] $Total = 10, [int] $Seed = 7, [switch] $Extras, [switch] $Opening, [switch] $Ascii, [switch] $NoColor, [switch] $NotStarted)
            $t = New-TestRenderer -Width $Width -Ascii:$Ascii -NoColor:$NoColor
            $r = $t.Renderer
            $r.Height = $Height; $r.FullScreen = $true; $r.GameSeed = $Seed; $r.GameCourseOnly = -not $Extras; $r.GameSkipOpening = -not $Opening
            $r.SetPhases(@('Prepare', 'Run tests', 'Results', 'Reports'))
            $r.SetStatusBar(@('maester.dev'), @('https://maester.dev'))
            $r.Open()
            if (-not $NotStarted) { $r.Start($Total) }
            $t
        }

        function Send-GameText {
            param($Renderer, [string] $Text)
            foreach ($c in $Text.ToCharArray()) { $Renderer.SendKey([ConsoleKey]0, $c) }
        }

        function Send-GameKey {
            param($Renderer, [ConsoleKey] $Key)
            $Renderer.SendKey($Key, [char]0)
        }

        function Complete-GameTest {
            param($Renderer, [string] $Id, [string] $Result = 'Failed', [string] $Severity = 'High', [string] $Title = "Title of $Id")
            $Renderer.ItemStarting($Id, $Title, $null)
            $Renderer.ItemFinished($Id, $Result, $Severity)
        }

        # Where things are on a screen of the game: the row of the ground, and the runner (its left column,
        # the rows it is above the ground, and whether it is in the air).
        function Get-GameView {
            param([string[]] $Screen)
            $ground = -1
            for ($y = $Screen.Count - 3; $y -gt 2; $y--) { if ($Screen[$y].StartsWith('▔▔▔')) { $ground = $y; break } }
            $row = -1
            for ($y = 2; $y -lt $ground; $y++) { if ($Screen[$y].Contains('▐███▌')) { $row = $y; break } }
            $x = $Screen[$row].IndexOf('▐███▌')
            [pscustomobject]@{
                Ground = $ground
                X      = $x
                Height = $ground - $row - 2
                Air    = $Screen[$row + 1].PadRight($x + 5).Substring($x, 5) -eq ' ▘ ▝ '
            }
        }

        # What is on the course of the game, as the game says it (GetGameCourse): the runner first, then
        # the platforms and everything else, with X in cells ahead of the right side of the runner and Y
        # in rows above the ground. -Kind gives only what is of those kinds, the nearest first.
        function Get-GameCourse {
            param($Renderer, [string[]] $Kind)
            $all = foreach ($line in $Renderer.GetGameCourse()) {
                $f = $line -split ' ', 8
                switch ($f[0]) {
                    'Runner' { [pscustomobject]@{ Kind = 'Runner'; Y = [double]$f[1]; Up = [double]$f[2]; Hearts = [int]$f[3]; Speed = [double]$f[4]; Stumbles = [double]$f[5]; State = $f[6]; Jumps = [int]$f[7] } }
                    'Platform' { [pscustomobject]@{ Kind = 'Platform'; From = [double]$f[1]; To = $(if ($f[2] -eq 'open') { [double]::MaxValue } else { [double]$f[2] }); Surface = [int]$f[3]; Route = $f[4] -eq 'route' } }
                    default { [pscustomobject]@{ Kind = $f[0]; X = [double]$f[1]; Y = [double]$f[2]; Width = [int]$f[3]; Height = [double]$f[4]; State = $f[5]; Count = [int]$f[6]; Id = $f[7] } }
                }
            }
            if ($Kind) { $all | Where-Object { $_.Kind -in $Kind } | Sort-Object X } else { $all }
        }

        # Lets the game run until the creature ahead is as near as -From, jumps (twice for the giant, the
        # second time at the top of the first jump), and lets the jump end. At the speed of a game that
        # just began, a jump from 15 cells comes down on a biter or on a brute, before either opens its
        # mouth, and two jumps from 20 come down on the giant.
        function Invoke-GameStomp {
            param($Renderer, [double] $From = 15, [switch] $Twice)
            for ($i = 0; $i -lt 1200; $i++) {
                $creature = @(Get-GameCourse $Renderer 'Walker', 'Attack', 'Biter', 'Brute', 'Giant' | Where-Object X -GT 0)[0]
                if ($creature -and $creature.X -le $From) { break }
                $Renderer.AdvanceGame(0.025)
            }
            Send-GameKey $Renderer Spacebar
            if ($Twice) {
                $Renderer.AdvanceGame(0.325)
                Send-GameKey $Renderer Spacebar
            }
            $Renderer.AdvanceGame(1.5)
        }

        # Lets the game run, with nobody at the key, until the runner was hit so many times, and says whether it was.
        function Wait-GameHit {
            param($Renderer, [int] $Hits = 1, [double] $Seconds = 12)
            for ($i = 0; $i -lt $Seconds * 40 -and $Renderer.GameResult.Hits -lt $Hits; $i++) { $Renderer.AdvanceGame(0.025) }
            $Renderer.GameResult.Hits -ge $Hits
        }

        # The first row of the game: the name, the hearts that are left of three, each on its own, and
        # the score and the streak.
        function Get-GameHud {
            param([int] $Hearts = 3, [string] $Score = '0', [string] $Streak = '0')
            '^ MAESTER RUN  ' + ((@('♥') * $Hearts + @('♡') * (3 - $Hearts)) -join ' ') + "  SCORE $Score  STREAK $Streak "
        }

        # Types the word: the wall begins to break at once.
        function Start-GameBreak {
            param($Renderer)
            Send-GameText $Renderer 'dead'
        }

        # The lines inside the first card on a screen, without its border and the spaces around them.
        function Get-GameCardText {
            param([string[]] $Screen)
            $top = @(0..($Screen.Count - 1) | Where-Object { $Screen[$_] -match '╭─+╮' })[0]
            if ($null -eq $top) { return }
            for ($i = $top + 1; $i -lt $Screen.Count -and $Screen[$i] -notmatch '╰─+╯'; $i++) {
                (($Screen[$i] -replace '^.*?│', '') -replace '│[^│]*$', '').Trim()
            }
        }

        # A terminal of so many rows and columns, as far as the frames of the dashboard need one: it
        # takes what was written and has the characters that are on its screen then. The cursor is put
        # somewhere, a line or the rest of the screen is erased, text is written; colours are left out.
        function New-TestScreen {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param([int] $Width, [int] $Height)
            [pscustomobject]@{ Width = $Width; Height = $Height; Row = 0; Column = 0; Cells = @(1..$Height | ForEach-Object { , [char[]](' ' * $Width) }) }
        }

        function Update-TestScreen {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
            param($Screen, [string] $Text)
            foreach ($token in [regex]::Matches($Text, "\x1b\[([0-9;?]*)([A-Za-z])|\x1b\][^\x07]*\x07|\r|\n|[^\x1b\r\n]+")) {
                $value = $token.Value
                if ($value -eq "`r") { $Screen.Column = 0; continue }
                if ($value -eq "`n") { $Screen.Row = [math]::Min($Screen.Height - 1, $Screen.Row + 1); continue }
                if ($value[0] -ne [char]27) {
                    foreach ($c in $value.ToCharArray()) {
                        if ($Screen.Column -lt $Screen.Width) { $Screen.Cells[$Screen.Row][$Screen.Column] = $c }
                        $Screen.Column++
                    }
                    continue
                }
                $numbers = @($token.Groups[1].Value -split ';' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
                switch -CaseSensitive ($token.Groups[2].Value) {
                    'H' { $Screen.Row = $(if ($numbers.Count -gt 0) { $numbers[0] - 1 } else { 0 }); $Screen.Column = $(if ($numbers.Count -gt 1) { $numbers[1] - 1 } else { 0 }) }
                    'K' { for ($x = $Screen.Column; $x -lt $Screen.Width; $x++) { $Screen.Cells[$Screen.Row][$x] = ' ' } }
                    'J' {
                        for ($x = $Screen.Column; $x -lt $Screen.Width; $x++) { $Screen.Cells[$Screen.Row][$x] = ' ' }
                        for ($y = $Screen.Row + 1; $y -lt $Screen.Height; $y++) { $Screen.Cells[$y] = [char[]](' ' * $Screen.Width) }
                    }
                }
            }
        }

        function Get-TestScreen {
            param($Screen)
            foreach ($cells in $Screen.Cells) { ([string]::new($cells)).TrimEnd() }
        }

        # The screen as the last frame of a tick has it, without its colours: the lines of that frame
        # as a whole, which the renderer keeps to tell what changes in the next one. (Not the text
        # GetPlainScreen gives a moment later: the time left and the spinner are of the clock, and the
        # large counter behind the game is of dots without colour and of dim blocks with it.)
        function Get-ShownScreen {
            param($Renderer)
            $flags = [System.Reflection.BindingFlags]'NonPublic, Instance'
            $lines = [Maester.Engine.MtConsoleRenderer].GetField('_shownLines', $flags).GetValue($Renderer)
            foreach ($line in $lines) { ($line -replace "$([char]27)\[[0-9;]*m").TrimEnd() }
        }

        # The top of a screen of the game as one line, whichever form it has. A screen with the room has
        # a band of five rows there: the name in letters of blocks, the hearts as sprites, the score in
        # large digits. This reads the band and says the same as the one line of a smaller screen does:
        # the hearts from their sprites, and the score from the dots of its digits.
        function Get-GameTopLine {
            param([string[]] $Screen)
            if ($Screen[0] -match '^ (MAESTER )?RUN  ') { return $Screen[0] }
            $glyphs = @{
                '█▀█|█ █|▀▀▀' = '0'; '▄█ | █ |▀▀▀' = '1'; '▀▀█|█▀▀|▀▀▀' = '2'; '▀▀█|▀▀█|▀▀▀' = '3'; '█ █|▀▀█|  ▀' = '4'
                '█▀▀|▀▀█|▀▀▀' = '5'; '█▀▀|█▀█|▀▀▀' = '6'; '▀▀█|  █|  ▀' = '7'; '█▀█|█▀█|▀▀▀' = '8'; '█▀█|▀▀█|▀▀▀' = '9'
            }
            $rows = @($Screen[0..4] | ForEach-Object { $_.PadRight(400) })
            $hearts = @([regex]::Matches($rows[1], '▟▙▟▙|╭╮╭╮') | ForEach-Object { if ($_.Value -eq '▟▙▟▙') { '♥' } else { '♡' } }) -join ' '
            $at = $rows[0].IndexOf('SCORE')
            $score = ''
            while ($true) {
                $digit = $glyphs[(($rows[1..3] | ForEach-Object { $_.Substring($at, 3) }) -join '|')]
                if ($digit) { $score += $digit; $at += 4; continue }
                if ((($rows[1..3] | ForEach-Object { $_.Substring($at, 2) }) -join '|') -eq '  | ▄|▀ ') { $score += ','; $at += 3; continue }
                break
            }
            $streak = [regex]::Match($rows[4], 'STREAK (\d+)').Groups[1].Value
            $best = [regex]::Match($rows[4], 'BEST [\d,]+').Value
            " MAESTER RUN  $hearts  SCORE $score  STREAK $streak $(if ($best) { " $best " })   $($rows[1].Substring($at).Trim())  $($rows[2].Substring($at).Trim())"
        }

        # Plays the game for so many seconds as a player does who misses nothing, from what is on the
        # course. It follows the route: a jump onto a bridge of the route that starts a level up, and a
        # jump from a spring. It jumps on a walker, an attack, a packet, a biter or a brute on its floor
        # so that it comes down on it, twice for the giant and for DC01 when it charges, over a plant that
        # is up as early as a jump clears it, and on a bird that comes at the height it stands at. With
        # -Route it only follows the route, and with -NotBoss it does nothing about DC01. It gives back
        # the kinds of what it saw on the course.
        function Invoke-GameBot {
            param($Renderer, [double] $Seconds, [switch] $Route, [switch] $NotBoss)
            $seen = @{}
            $was = @{}
            for ($i = 0; $i -lt [math]::Round($Seconds * 40); $i++) {
                # The second of two jumps is due so many steps after the first, also when that was in an earlier call.
                $script:gameBotSecond--
                $course = @(Get-GameCourse $Renderer)
                $me = $course[0]
                $stands = $me.State -eq 'stands'
                $floor = [math]::Round($me.Y)
                $now = @{}
                $jump = $false
                foreach ($thing in $course) {
                    if ($thing.Kind -in 'Runner', 'Platform', 'Coin') { continue }
                    $seen[$thing.Kind] = $true
                    # How fast it comes nearer: from where it was a step ago.
                    $key = "$($thing.Kind) $($thing.Id)"
                    while ($now.ContainsKey($key)) { $key += '+' }
                    $now[$key] = $thing.X
                    $closing = if ($was.ContainsKey($key) -and $was[$key] - $thing.X -gt $me.Speed / 40 - 0.02) { ($was[$key] - $thing.X) * 40 } else { $me.Speed }
                    if (-not $stands) { continue }
                    if ($thing.Kind -eq 'Spring') {
                        if ([math]::Abs($thing.Y - $floor) -lt 0.5 -and $thing.X -le -1.5 -and $thing.X -ge -10.5) { $jump = $true }
                        continue
                    }
                    if ($Route) { continue }
                    $soon = $thing.X / $closing
                    if ($thing.Kind -eq 'Boss') {
                        if (-not $NotBoss -and $thing.State -eq 'charges' -and $thing.X -gt 0 -and $thing.X / (42 + 2 * (4 - $thing.Count)) -le 0.93) { $jump = $true; $script:gameBotSecond = 12 }
                    }
                    elseif ($thing.Kind -eq 'Bird') {
                        if ($thing.State -eq 'flies' -and $thing.X -gt -2 -and $thing.Y -lt $floor + 3 -and $thing.Y + 2 -gt $floor -and $soon -le 0.55) { $jump = $true }
                    }
                    elseif ($thing.X -gt 0 -and [math]::Abs($thing.Y - $floor) -lt 0.5) {
                        if ($thing.Kind -in 'Walker', 'Attack', 'Packet' -and $soon -le 0.56) { $jump = $true }
                        # A mouth that opens is answered, a moment after it opened.
                        if ($thing.Kind -eq 'Biter' -and ($soon -le 0.57 -or ($thing.State -eq 'opens' -and $soon -le 0.66))) { $jump = $true }
                        if ($thing.Kind -eq 'Brute' -and ($soon -le 0.52 -or ($thing.State -eq 'opens' -and $soon -le 0.66))) { $jump = $true }
                        if ($thing.Kind -eq 'Giant' -and $soon -le 0.9) { $jump = $true; $script:gameBotSecond = 12 }
                        if ($thing.Kind -eq 'Plant' -and $thing.Height -gt 1.2 -and $thing.X -le 0.579 * $me.Speed - 6.7) { $jump = $true }
                    }
                }
                $was = $now
                if ($stands -and -not $jump) {
                    # A jump takes the runner the next level up in 0.44 seconds.
                    $lands = $me.Speed * 0.442
                    foreach ($platform in $course | Where-Object { $_.Kind -eq 'Platform' -and $_.Route }) {
                        if ($platform.Surface -eq $floor + 4 -and $platform.From + 2.5 -le $lands - 1 -and $platform.To + 2.5 -gt $lands + 4) { $jump = $true }
                    }
                }
                if ($jump -or $script:gameBotSecond -eq 0) { Send-GameKey $Renderer Spacebar }
                $Renderer.AdvanceGame(0.025)
            }
            @($seen.Keys)
        }

        # Follows the route for so many seconds, and does nothing about what is in the way.
        function Invoke-GameCourse {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'The size is of the callers of an earlier form of this helper.')]
            param($Renderer, [double] $Seconds, [int] $Width = 80, [int] $Height = 24)
            $null = Invoke-GameBot $Renderer -Seconds $Seconds -Route
        }

        # How far the ground went by in so many seconds, in cells: from the dots under it, which are nine apart.
        function Measure-GameGround {
            param($Renderer, [double] $Seconds, [int] $Width = 80, [int] $Height = 24)
            $cells = 0
            $was = $null
            for ($i = 0; $i -le $Seconds * 40; $i++) {
                if ($i -gt 0) { $Renderer.AdvanceGame(0.025) }
                $screen = $Renderer.GetPlainScreen($Width, $Height)
                $now = $screen[(Get-GameView $screen).Ground + 1].IndexOf('·')
                if ($null -ne $was) { $cells += (($was - $now) % 9 + 9) % 9 }
                $was = $now
            }
            $cells
        }
    }

    It 'Ignores the word while no tests run: before they start, after they stop, and outside the dashboard' {
        $t = New-GameDashboard -NotStarted
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.Start(10)
        # Letters from before the tests started do not count.
        Send-GameText $t.Renderer 'ad'
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.Stop()
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.Close()

        # The compact layout has no game.
        $t = New-TestRenderer
        $t.Renderer.Start(10)
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.Stop()
    }

    It 'Ends the game with a card when the tests stop, takes Esc only, and delays nothing' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 10
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..3 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(8) }
        Complete-GameTest $r 'F.1' -Severity 'Low'
        Invoke-GameStomp $r
        Complete-GameTest $r 'F.2' -Severity 'Low'
        $r.AdvanceGame(8)
        $result = $r.GameResult
        $result.Score | Should -Be 3500
        $r.Stop()
        $r.IsRunning | Should -BeFalse
        $r.IsGameShown | Should -BeTrue
        $card = $r.GetPlainScreen(165, 52)
        $text = $card -join "`n"
        $text | Should -Match 'RUN COMPLETE'
        $text | Should -Match 'SCORE 3,500 of 10,000'
        $text | Should -Match '3 coins · 1 stomp · best streak 4 · 1 hit'
        $text | Should -Match 'in the game only: 2 still need you for real'
        $card[51] | Should -Match '^ +Esc back to the dashboard $'
        # No key but Esc does anything, and the game does not move.
        Send-GameKey $r Spacebar
        Send-GameKey $r Enter
        Send-GameText $r 'pqm'
        $r.AdvanceGame(3)
        $r.GetPlainScreen(165, 52) | Should -Be $card
        $r.IsGameShown | Should -BeTrue
        # The phases that follow go on under the card.
        $r.StartPhase('Results')
        $r.IsGameShown | Should -BeTrue
        Send-GameKey $r Escape
        $r.IsGameShown | Should -BeFalse
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match '● Results'
        # And the word does not bring it back.
        Send-GameText $r 'dead'
        $r.IsGameShown | Should -BeFalse
        # The result of the game is kept for after the run, also when the screen is given back.
        $r.Close()
        $r.GameScore | Should -Be 3500
        $after = $r.GameResult
        $after.Coins | Should -Be 3
        $after.Stomps | Should -Be 1
        $after.Hits | Should -Be 1
        $after.BestStreak | Should -Be 4
        $after.Tests | Should -Be 10
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?25h$esc[?1049l") + '$')
    }

    It 'Closes with the game on screen as it does without it, and starts a new run without a game' {
        $t = New-GameDashboard
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.Stop()
        $t.Renderer.Close()
        $t.Renderer.IsFullScreen | Should -BeFalse
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?25h$esc[?1049l") + '$')
        # A game that was left before the tests stopped shows nothing when they do.
        $t = New-GameDashboard
        Send-GameText $t.Renderer 'dead'
        Send-GameKey $t.Renderer Escape
        $t.Renderer.Stop()
        $t.Renderer.IsGameShown | Should -BeFalse
        ($t.Renderer.GetPlainScreen(80, 24) -join "`n") | Should -Not -Match 'RUN COMPLETE|MAESTER RUN'
        $t.Renderer.GameScore | Should -Be 0
        # A new run starts without a game.
        $t.Renderer.Start(5)
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.GameScore | Should -BeNullOrEmpty
        $t.Renderer.GameResult | Should -BeNullOrEmpty
        $t.Renderer.Close()
    }

    It 'Keeps the best score of the user in a file: the number and the day, and nothing else' {
        $path = Join-Path $TestDrive 'state/sub/run-best.txt'
        # A game of 3,000 points, and one of -Coins thousand.
        $play = {
            param([int] $Coins, [string] $Path)
            $t = New-GameDashboard -Total 10
            $r = $t.Renderer
            $r.SetTenant('Contoso', 'contoso.example', 'admin@contoso.example')
            $r.GameBestPath = $Path
            Send-GameText $r 'dead'
            # The file is read by another thread when the game starts.
            for ($i = 0; $i -lt 100 -and $Path -and (Test-Path -LiteralPath $Path -PathType Leaf) -and $r.GameResult.Best -eq 0 -and (Get-Content -LiteralPath $Path -Raw) -match '^\d{1,5} \d{4}-\d\d-\d\d\s*$'; $i++) { Start-Sleep -Milliseconds 20 }
            for ($n = 1; $n -le $Coins; $n++) { Complete-GameTest $r "P.$n" -Result 'Passed'; if ($n % 3 -eq 0) { Complete-GameTest $r "S.$n" -Result 'Skipped' }; Invoke-GameCourse $r -Seconds 4 }
            $r.Stop()
            $r.Close()
            $r
        }
        # Nothing is written before it is asked for, and the folder need not exist.
        $r = & $play 3 $path
        $r.GameScore | Should -Be 3000
        Test-Path -LiteralPath $path | Should -BeFalse
        $r.GameResult.Best | Should -Be 0
        $r.GameResult.NewBest | Should -BeFalse
        $r.SaveGameBest() | Should -BeTrue
        $today = [datetime]::Now.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
        (Get-Content -LiteralPath $path -Raw) | Should -Be "3000 $today`n"
        $result = $r.GameResult
        $result.Best | Should -Be 3000
        $result.BestDate | Should -Be $today
        $result.NewBest | Should -BeTrue
        # Once: the same score is not a new best a second time.
        $r.SaveGameBest() | Should -BeFalse

        # The next game reads it: it is in the first row, and a lower score does not replace it.
        Set-Content -LiteralPath $path -Value '3000 2026-01-31' -NoNewline
        $t = New-GameDashboard -Width 165 -Height 52 -Total 10
        $t.Renderer.GameBestPath = $path
        Send-GameText $t.Renderer 'dead'
        for ($i = 0; $i -lt 100 -and $t.Renderer.GameResult.Best -eq 0; $i++) { Start-Sleep -Milliseconds 20 }
        $t.Renderer.GameResult.Best | Should -Be 3000
        $t.Renderer.GameResult.BestDate | Should -Be '2026-01-31'
        (Get-GameTopLine $t.Renderer.GetPlainScreen(165, 52)) | Should -Match ((Get-GameHud) + ' BEST 3,000 ')
        $t.Renderer.Close()
        $r = & $play 2 $path
        $r.SaveGameBest() | Should -BeFalse
        $r.GameResult.NewBest | Should -BeFalse
        $r.GameResult.Best | Should -Be 3000
        (Get-Content -LiteralPath $path -Raw) | Should -Be '3000 2026-01-31'
        # A higher one does.
        $r = & $play 4 $path
        $r.SaveGameBest() | Should -BeTrue
        (Get-Content -LiteralPath $path -Raw) | Should -Be "4000 $today`n"
        # Nothing of the tenant is in the file.
        (Get-Content -LiteralPath $path -Raw) | Should -Not -Match 'ontoso|admin|example'

        # A file that is not a best score counts as none, and is replaced by the next score.
        foreach ($broken in 'garbage', '99999 2026-01-31', '500', '500 yesterday', '-5 2026-01-31', ('x' * 5000), '') {
            Set-Content -LiteralPath $path -Value $broken -NoNewline
            $r = & $play 1 $path
            $r.GameResult.Best | Should -Be 0
            $r.SaveGameBest() | Should -BeTrue
            (Get-Content -LiteralPath $path -Raw) | Should -Be "1000 $today`n"
        }
        # A game with no points is not a best score.
        Remove-Item -LiteralPath $path
        $r = & $play 0 $path
        $r.SaveGameBest() | Should -BeFalse
        Test-Path -LiteralPath $path | Should -BeFalse
        # A place that cannot be written, or no place at all: no best score, and no error.
        $r = & $play 1 (Join-Path $TestDrive 'state')
        { $r.SaveGameBest() } | Should -Not -Throw
        $r.SaveGameBest() | Should -BeFalse
        $r = & $play 1 $null
        $r.SaveGameBest() | Should -BeFalse
        $r.GameResult.Best | Should -Be 0
        # And none for a run in which the game was not played.
        $t = New-GameDashboard
        $t.Renderer.GameBestPath = $path
        $t.Renderer.Stop()
        $t.Renderer.SaveGameBest() | Should -BeFalse
        Test-Path -LiteralPath $path | Should -BeFalse
        $t.Renderer.Close()
    }

    It 'Draws nothing that a test put in its ID or its title' {
        $bel = [char]7
        $attacks = @("$esc]0;PWNED$bel", "$esc]52;c;AAAA$bel", "$esc[?1049l", "$esc[2J", "$([char]0x9B)2J")
        $t = New-GameDashboard
        $r = $t.Renderer
        $evil = $attacks -join 'x'
        # In the name over a creature, and in the ticker when it is stomped.
        Complete-GameTest $r "ID.1$evil" -Severity 'Low' -Title "Title one$evil`r`nsecond line"
        Send-GameText $r 'dead'
        Invoke-GameStomp $r
        $r.GameResult.Stomps | Should -Be 1
        # And in the ticker when a coin is collected.
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ✓ Stomped ID\.1 \]0;PWNED x \]52;c;AAAA x '
        Complete-GameTest $r "ID.2$evil" -Result 'Passed' -Title "Title two$evil`r`nsecond line"
        $r.AdvanceGame(5)
        $r.GameResult.Coins | Should -Be 1
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ● Collected ID\.2 \]0;PWNED x '
        $r.Stop()
        $out = $t.Writer.ToString()
        $out | Should -Match 'Stomped '
        $out | Should -Match 'ID\.1 \]0;PWNED'
        foreach ($attack in $attacks) { $out.Contains($attack) | Should -BeFalse }
        $out.Contains("one`r`nsecond") | Should -BeFalse
        $r.Close()
    }

    It 'Leaves the run as it is: the same counts and the same dashboard with the game as without it' {
        $play = {
            param([bool] $Game)
            $t = New-GameDashboard -Width 165 -Height 52 -Total 40
            $r = $t.Renderer
            1..10 | ForEach-Object { Complete-GameTest $r "F.$_" -Severity 'Medium' }
            if ($Game) {
                Send-GameText $r 'dead'
                $r.AdvanceGame(2)
                Send-GameKey $r Spacebar
            }
            1..10 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
            1..5 | ForEach-Object { Complete-GameTest $r "G.$_" -Severity 'High' }
            if ($Game) {
                Invoke-GameCourse $r -Seconds 6 -Width 165 -Height 52
                Send-GameKey $r Escape
            }
            $r.Stop()
            $counts = '{0} {1} {2} {3} {4}' -f $r.Total, $r.Finished, $r.Passed, $r.Failed, $r.Errors
            # The times on the dashboard are of the clock: they are not compared.
            $screen = $r.GetPlainScreen(165, 52) | ForEach-Object { $_ -replace '\d+(\.\d+)?[sm]\b', 'T' -replace '\d+:\d\d', 'T' }
            $r.Close()
            @{ Counts = $counts; Screen = $screen }
        }
        $with = & $play $true
        $without = & $play $false
        $with.Counts | Should -Be '40 25 10 15 0'
        $with.Counts | Should -Be $without.Counts
        $with.Screen | Should -Be $without.Screen
    }

    It 'Plays no sound from a renderer that writes somewhere else than the console' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.3)
        Send-GameKey $r Spacebar
        @($r.TakeGameSounds()).Count | Should -Be 2
        # The sounds were asked for, and that is all: there is nothing that plays them.
        $audio = [Maester.Engine.MtConsoleRenderer].GetField('_audio', [System.Reflection.BindingFlags]'NonPublic, Instance')
        $audio | Should -Not -BeNullOrEmpty
        $audio.GetValue($r) | Should -BeNullOrEmpty
        $r.Close()
    }

    It 'Writes a frame of the tick as what changed since the frame before: a terminal that takes them has the screen of the game' {
        $t = New-GameDashboard -Width 124 -Height 40 -Total 400 -Seed 21 -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $terminal = New-TestScreen -Width 124 -Height 40
        $n = 0
        foreach ($i in 1..66) {
            if ($i % 6 -eq 0) { $n++; $r.ItemStarting("T.$n", 'A test', $null); $r.ItemFinished("T.$n", $(if ($n % 3) { 'Passed' } else { 'Failed' }), 'Low') }
            $null = Invoke-GameBot $r -Seconds 0.05
            $mark = $t.Writer.ToString().Length
            $r.Tick()
            $written = $t.Writer.ToString().Substring($mark)
            # One frame, written at once where the terminal can do that.
            $written | Should -Match ('^' + [regex]::Escape("$esc[?2026h"))
            $written | Should -Match ([regex]::Escape("$esc[?2026l") + '$')
            ([regex]::Matches($written, [regex]::Escape("$esc[?2026h"))).Count | Should -Be 1
            Update-TestScreen $terminal $written
            # The terminal has what the frame has as a whole, row for row, and that is the screen of the game.
            $shown = @(Get-TestScreen $terminal)
            $shown | Should -Be @(Get-ShownScreen $r)
            @($shown | ForEach-Object { $_ -replace '[█·]', '#' -replace 'ETA \d+:\d\d', 'ETA' }) |
                Should -Be @($r.GetPlainScreen(124, 40) | ForEach-Object { $_.TrimEnd() -replace '[█·]', '#' -replace 'ETA \d+:\d\d', 'ETA' })
        }
        # (A result is written at once where there are no ticks, as in these tests: the frame after one is whole.)
        $r.Close()

        # Without anything else written in between: the first frame is the whole screen, and the next
        # ones are what changed, a small part of it. Each of them also has one line of the screen as a
        # whole, the next one each time: whatever else got on the screen is gone when all had their
        # turn, and no frame is the size of the whole screen for that.
        $t = New-GameDashboard -Width 124 -Height 40 -Total 400 -Seed 21 -Extras
        $r = $t.Renderer
        1..9 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        $terminal = New-TestScreen -Width 124 -Height 40
        $frames = foreach ($i in 1..45) {
            $null = Invoke-GameBot $r -Seconds 0.05
            $mark = $t.Writer.ToString().Length
            $r.Tick()
            $written = $t.Writer.ToString().Substring($mark)
            Update-TestScreen $terminal $written
            (Get-TestScreen $terminal) | Should -Be @(Get-ShownScreen $r)
            [pscustomobject]@{
                Length = $written.Length
                Whole  = $written.StartsWith("$esc[?2026h$esc[H")
                Moves  = ([regex]::Matches($written, "$esc\[\d+;\d+H")).Count
                Lines  = @([regex]::Matches($written, "$esc\[(\d+);1H") | ForEach-Object { [int]$_.Groups[1].Value })
            }
        }
        @(0..44 | Where-Object { $frames[$_].Whole }) | Should -Be @(0)
        $part = @($frames | Where-Object { -not $_.Whole })
        ($part.Length | Measure-Object -Maximum).Maximum | Should -BeLessThan ($frames[0].Length / 2)
        ($part.Length | Measure-Object -Average).Average | Should -BeLessThan ($frames[0].Length / 4)
        # What changed is written where it is: the cursor is put there.
        ($part.Moves | Measure-Object -Minimum).Minimum | Should -BeGreaterThan 0
        $frames[0].Moves | Should -Be 0
        # The line that has its turn: the first after the whole screen, then the second, and after the
        # fortieth the first again.
        foreach ($k in 1..44) { $frames[$k].Lines | Should -Contain ((($k - 1) % 40) + 1) }
        # Something else gets on the screen, and nothing tells the renderer: it is gone when every line had its turn.
        Update-TestScreen $terminal "$esc[12;30Hsomething else$esc[31;5Hand more"
        (Get-TestScreen $terminal) | Should -Not -Be @(Get-ShownScreen $r)
        foreach ($i in 1..40) {
            $null = Invoke-GameBot $r -Seconds 0.05
            $mark = $t.Writer.ToString().Length
            $r.Tick()
            Update-TestScreen $terminal $t.Writer.ToString().Substring($mark)
        }
        (Get-TestScreen $terminal) | Should -Be @(Get-ShownScreen $r)

        # After anything else was written, the next frame is whole: the screen is no longer what the last frame left.
        $r.ItemFinished('Skipped')
        $mark = $t.Writer.ToString().Length
        $r.Tick()
        $t.Writer.ToString().Substring($mark).StartsWith("$esc[?2026h$esc[H") | Should -BeTrue
        $r.Close()

        # The dashboard is written the same way: its lines that changed, and nothing where nothing did.
        $t = New-GameDashboard -Width 124 -Height 40 -Total 400
        $r = $t.Renderer
        1..9 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $terminal = New-TestScreen -Width 124 -Height 40
        $frames = foreach ($i in 1..5) {
            $mark = $t.Writer.ToString().Length
            $r.Tick()
            $written = $t.Writer.ToString().Substring($mark)
            Update-TestScreen $terminal $written
            (Get-TestScreen $terminal) | Should -Be @(Get-ShownScreen $r)
            [pscustomobject]@{ Whole = $written.StartsWith("$esc[?2026h$esc[H"); Lines = ([regex]::Matches($written, "$esc\[\d+;1H")).Count }
        }
        $frames[0].Whole | Should -BeTrue
        @($frames[1..4] | Where-Object Whole).Count | Should -Be 0
        # Of its forty lines, a frame has the few that the clock changed (the spinner, the times) and
        # the two that have their turn: not the nine results, which stay as they are.
        ($frames[1..4].Lines | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 10
        ($frames[1..4].Lines | Measure-Object -Minimum).Minimum | Should -BeGreaterOrEqual 2
        # Two of its lines have their turn in a frame: all forty in twenty frames.
        Update-TestScreen $terminal "$esc[2;30Hsomething else$esc[38;5Hand more"
        (Get-TestScreen $terminal) | Should -Not -Be @(Get-ShownScreen $r)
        foreach ($i in 1..20) {
            $mark = $t.Writer.ToString().Length
            $r.Tick()
            Update-TestScreen $terminal $t.Writer.ToString().Substring($mark)
        }
        (Get-TestScreen $terminal) | Should -Be @(Get-ShownScreen $r)
        $r.Close()
    }

    It 'Does not write a frame that was worked out before something else was written' {
        $t = New-GameDashboard -Width 124 -Height 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $flags = [System.Reflection.BindingFlags]'NonPublic, Instance'
        $build = [Maester.Engine.MtConsoleRenderer].GetMethod('BuildTickFrame', $flags)
        $write = [Maester.Engine.MtConsoleRenderer].GetMethod('WriteFrame', $flags)
        $serial = [Maester.Engine.MtConsoleRenderer].GetField('_writeSerial', $flags)
        # A frame, and the number of the last write when it was worked out: it is written.
        $frame = $build.Invoke($r, $null)
        $mark = $t.Writer.ToString().Length
        $write.Invoke($r, @($frame, [long]$serial.GetValue($r))) | Should -BeTrue
        $t.Writer.ToString().Length | Should -Be ($mark + $frame.Length)
        # Another one, and then the game is left before it is written: it is of a screen that is gone.
        $frame = $build.Invoke($r, $null)
        $number = [long]$serial.GetValue($r)
        Send-GameKey $r Escape
        $mark = $t.Writer.ToString().Length
        $write.Invoke($r, @($frame, $number)) | Should -BeFalse
        $t.Writer.ToString().Length | Should -Be $mark
        # And the same when the screen was given back in between.
        Send-GameText $r 'dead'
        $frame = $build.Invoke($r, $null)
        $number = [long]$serial.GetValue($r)
        $r.Close()
        $mark = $t.Writer.ToString().Length
        $write.Invoke($r, @($frame, $number)) | Should -BeFalse
        $t.Writer.ToString().Length | Should -Be $mark
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[?1049l") + '$')
    }

    It 'Draws the dashboard that owns the screen from a thread of its own: its frames do not wait for the thread pool, and a result does not wait for a frame' {
        # With ticks, a result writes nothing: the next tick draws it. The ticks of this one are five seconds apart.
        $t = New-TestRenderer -Width 120
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true; $r.RefreshIntervalMs = 5000
        $r.Open()
        $r.Start(400)
        $mark = $t.Writer.ToString().Length
        1..100 | ForEach-Object { $r.ItemStarting("T.$_", 'A test', $null); $r.ItemFinished("T.$_", 'Passed', 'Low') }
        $t.Writer.ToString().Length | Should -Be $mark
        $r.GetPlainScreen(120, 40)[1] | Should -Match ' 100/400 '
        # Nor does a key, or the end of the tests: the wall that the word breaks, the game and the
        # dashboard after the run are drawn by the next tick. The run and the keys never wait for a
        # console that is slow to take a frame.
        Send-GameText $r 'dead'
        $r.IsGameShown | Should -BeTrue
        $r.Stop()
        $t.Writer.ToString().Length | Should -Be $mark
        $r.Tick()
        $t.Writer.ToString().Length | Should -BeGreaterThan ($mark + 1000)
        $r.Close()
        # Without ticks, as in most of these tests, every one of them draws.
        $t = New-TestRenderer -Width 120
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true
        $r.Open()
        $r.Start(400)
        $mark = $t.Writer.ToString().Length
        1..10 | ForEach-Object { $r.ItemStarting("T.$_", 'A test', $null); $r.ItemFinished("T.$_", 'Passed', 'Low') }
        ([regex]::Matches($t.Writer.ToString().Substring($mark), [regex]::Escape("$esc[?2026h"))).Count | Should -Be 20
        $r.Close()

        # Every thread of the pool is held by work that waits, and more of it is queued: a timer of the
        # runtime would wait with it. The frames of the game go on, twenty a second.
        $t = New-TestRenderer -Width 120
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true; $r.RefreshIntervalMs = 100; $r.GameSeed = 7; $r.GameSkipOpening = $true
        $r.Open()
        $r.Start(400)
        Send-GameText $r 'dead'
        $hold = [System.Threading.ManualResetEventSlim]::new($false)
        $wait = [Delegate]::CreateDelegate([Action], $hold, [System.Threading.ManualResetEventSlim].GetMethod('Wait', [type[]]@()))
        $workers = 0; $ports = 0
        [System.Threading.ThreadPool]::GetMinThreads([ref]$workers, [ref]$ports)
        try {
            $held = @(1..(4 * $workers + 64) | ForEach-Object { [System.Threading.Tasks.Task]::Run($wait) })
            Start-Sleep -Milliseconds 300
            $before = $(if ($r.GameFrameTiming) { $r.GameFrameTiming.Frames } else { 0 })
            Start-Sleep -Milliseconds 1000
            $during = $r.GameFrameTiming.Frames - $before
        } finally {
            $hold.Set()
            [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$held, 10000) | Out-Null
        }
        # (Twenty on a machine that has the time. A timer of the thread pool has none in that second.)
        $during | Should -BeGreaterThan 6
        $r.Close()
    }

    It 'Reads no keys from the console unless ReadKeys is on, and never for a renderer that writes somewhere else' {
        foreach ($readKeys in $false, $true) {
            $t = New-TestRenderer -Width 120
            $r = $t.Renderer
            $r.Height = 40; $r.FullScreen = $true; $r.RefreshIntervalMs = 10; $r.ReadKeys = $readKeys
            $r.Open()
            $r.Start(5)
            Start-Sleep -Milliseconds 200
            $r.KeyPollCount | Should -Be 0
            # The timer does draw: that it did not ask for keys is not because it did not run.
            ([regex]::Matches($t.Writer.ToString(), [regex]::Escape("$esc[?2026h"))).Count | Should -BeGreaterThan 3
            $r.Close()
        }
        [Maester.Engine.MtConsoleRenderer]::new([System.IO.StringWriter]::new()).ReadKeys | Should -BeFalse
    }

    It 'Moves the game with the timer when there is one, and gives the dashboard its own pace back' {
        $t = New-TestRenderer -Width 120
        $r = $t.Renderer
        $r.Height = 40; $r.FullScreen = $true; $r.RefreshIntervalMs = 40; $r.GameSeed = 7; $r.GameSkipOpening = $true
        $r.Open()
        $r.Start(5)
        Complete-GameTest $r 'F.1'
        Send-GameText $r 'dead'
        Start-Sleep -Milliseconds 300
        $where = { $line = @($r.GetPlainScreen(120, 40)[2..37] | Where-Object { $_ -match 'F\.1' })[0]; "$($line.IndexOf('F.1'))" }
        $start = & $where
        $start | Should -Not -Be '-1'
        Start-Sleep -Milliseconds 500
        # Nobody moved the time on: the timer did, and the creature came nearer.
        [int](& $where) | Should -BeLessThan ([int]$start)
        Send-GameKey $r Escape
        $mark = $t.Writer.ToString().Length
        Start-Sleep -Milliseconds 300
        $after = $t.Writer.ToString().Substring($mark)
        $after | Should -Match ([regex]::Escape("$esc[?2026h"))
        $after | Should -Not -Match 'MAESTER RUN'
        $r.KeyPollCount | Should -Be 0
        $r.Close()
    }
}

Describe 'MtConsoleFeeds links and titles' {
    It 'Takes only https links from a feed, and drops characters that reorder text from titles' {
        $xml = "<rss><channel>" +
            "<item><title>Safe$([char]0x202E)post</title><link>https://maester.dev/blog/a</link><pubDate>Tue, 07 Oct 2026 10:00:00 GMT</pubDate></item>" +
            "<item><title>Plain http</title><link>http://maester.dev/blog/b</link></item>" +
            "<item><title>Script</title><link>javascript:alert(1)</link></item>" +
            "</channel></rss>"
        $posts = [Maester.Engine.MtConsoleFeeds]::ParseFeed($xml, 5)
        $posts[0].Title | Should -Be 'Safepost'
        $posts[0].Link | Should -Be 'https://maester.dev/blog/a'
        $posts[1].Link | Should -BeNullOrEmpty
        $posts[2].Link | Should -BeNullOrEmpty
    }
}
