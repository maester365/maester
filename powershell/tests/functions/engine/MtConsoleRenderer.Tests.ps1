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

    It 'Starts the game when the word is typed while tests run, in any case' {
        $t = New-GameDashboard -Width 165 -Height 52
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.GameScore | Should -BeNullOrEmpty
        $t.Renderer.GameResult | Should -BeNullOrEmpty
        Send-GameText $t.Renderer 'DeA'
        $t.Renderer.IsGameShown | Should -BeFalse
        Send-GameText $t.Renderer 'D'
        $t.Renderer.IsGameShown | Should -BeTrue
        $screen = $t.Renderer.GetPlainScreen(165, 52)
        $screen.Count | Should -Be 52
        (Get-GameTopLine $screen) | Should -Match (Get-GameHud)
        $t.Renderer.GameScore | Should -Be 0
        $t.Renderer.Close()
    }

    It 'Starts the word again after another key, and after two seconds without one' {
        $t = New-GameDashboard
        Send-GameText $t.Renderer 'dexad'
        $t.Renderer.IsGameShown | Should -BeFalse
        Send-GameKey $t.Renderer LeftArrow
        Send-GameText $t.Renderer 'ead'
        $t.Renderer.IsGameShown | Should -BeFalse
        # The first letter of the word starts it again, also where another letter was due.
        Send-GameText $t.Renderer 'dedead'
        $t.Renderer.IsGameShown | Should -BeTrue
        Send-GameKey $t.Renderer Escape
        $t.Renderer.IsGameShown | Should -BeFalse

        Send-GameText $t.Renderer 'de'
        $t.Renderer.AdvanceGame(2.5)
        Send-GameText $t.Renderer 'ad'
        $t.Renderer.IsGameShown | Should -BeFalse
        Send-GameText $t.Renderer 'de'
        $t.Renderer.AdvanceGame(1.5)
        Send-GameText $t.Renderer 'ad'
        $t.Renderer.IsGameShown | Should -BeTrue
        $t.Renderer.Close()
    }

    It 'Ignores the word on a screen that is too small for the game (<Width>x<Height>)' -ForEach @(@{ Width = 80; Height = 23 }, @{ Width = 79; Height = 40 }) {
        $t = New-GameDashboard -Width $Width -Height $Height
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.IsGameShown | Should -BeFalse
        $t.Renderer.GameScore | Should -BeNullOrEmpty
        ($t.Renderer.GetPlainScreen($Width, $Height) -join "`n") | Should -Not -Match 'MAESTER RUN'
        $t.Renderer.Close()
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

    It 'Goes back to the dashboard on Esc or Q, keeps the game as it was, and goes on with it when the word is typed again' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        1..3 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        $r.AdvanceGame(3)
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.2)
        $before = $r.GetPlainScreen(165, 52)
        (Get-GameView $before).Air | Should -BeTrue
        Send-GameKey $r Escape
        $r.IsGameShown | Should -BeFalse
        $dashboard = $r.GetPlainScreen(165, 52) -join "`n"
        $dashboard | Should -Not -Match 'MAESTER RUN'
        $dashboard | Should -Match ' Running'
        # The game stands still while the dashboard is shown.
        $r.AdvanceGame(5)
        Send-GameText $r 'dead'
        $r.IsGameShown | Should -BeTrue
        # (The first row has the time the run still takes, which is of the clock.)
        $r.GetPlainScreen(165, 52)[1..51] | Should -Be $before[1..51]
        # And it moves again: the runner comes down.
        $r.AdvanceGame(1)
        (Get-GameView $r.GetPlainScreen(165, 52)).Air | Should -BeFalse
        Send-GameText $r 'q'
        $r.IsGameShown | Should -BeFalse
        $r.Close()
    }

    It 'Draws the dashboard again when the game is left, and the game over the whole screen when it is shown' {
        $t = New-GameDashboard -Width 165 -Height 52
        Send-GameText $t.Renderer 'dead'
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ' FINISH'
        (Get-GameTopLine $t.Renderer.GetPlainScreen(165, 52)) | Should -Match '^ MAESTER RUN '
        Send-GameKey $t.Renderer Escape
        $frame = $t.Writer.ToString()
        $last = $frame.Substring($frame.LastIndexOf("$esc[H"))
        $last | Should -Not -Match 'MAESTER RUN'
        $last | Should -Match 'maester\.dev'
        # Every row is erased to its end, and the rows under the last one: nothing of the game is left.
        $last | Should -Match ([regex]::Escape("$esc[J$esc[?2026l") + '$')
        $t.Renderer.Close()
    }

    It 'Jumps on Space, Up or W: four and a half rows up, and down again in two thirds of a second' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $view = Get-GameView $r.GetPlainScreen(80, 24)
        $view.Height | Should -Be 0
        $view.Air | Should -BeFalse
        $view.X | Should -Be 11
        # The heights of a jump, every twentieth of a second.
        $arc = {
            param([scriptblock] $Key)
            & $Key
            @(for ($i = 0; $i -lt 16; $i++) { $r.AdvanceGame(0.05); (Get-GameView $r.GetPlainScreen(80, 24)).Height })
        }
        $jump = & $arc { Send-GameKey $r Spacebar }
        ($jump | Measure-Object -Maximum).Maximum | Should -Be 5
        # Up, and down: on the ground again after 0.65 seconds, and it stays there.
        $jump[0..5] | Should -Be @(1, 2, 3, 4, 4, 5)
        $jump[11] | Should -BeGreaterThan 0
        $jump[13..15] | Should -Be @(0, 0, 0)
        (Get-GameView $r.GetPlainScreen(80, 24)).Air | Should -BeFalse
        # The runner stays where it is on the screen: the world goes by.
        (Get-GameView $r.GetPlainScreen(80, 24)).X | Should -Be 11
        (& $arc { Send-GameKey $r UpArrow }) | Should -Be $jump
        (& $arc { Send-GameText $r 'w' }) | Should -Be $jump
        (& $arc { Send-GameText $r 'W' }) | Should -Be $jump
        # No other key is a key of the game.
        (& $arc { Send-GameKey $r LeftArrow; Send-GameKey $r RightArrow; Send-GameKey $r DownArrow; Send-GameKey $r Enter; Send-GameText $r 'adsx' } | Measure-Object -Maximum).Maximum | Should -Be 0
        $r.Close()
    }

    It 'Jumps a second time in the air, and not a third: twice as high' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $heights = {
            param([double[]] $Keys)
            $now = 0.0
            @(for ($i = 0; $i -lt 40; $i++) {
                foreach ($at in $Keys) { if ([math]::Abs($at - $now) -lt 0.001) { Send-GameKey $r Spacebar } }
                $r.AdvanceGame(0.05)
                $now += 0.05
                (Get-GameView $r.GetPlainScreen(80, 24)).Height
            })
        }
        # The second jump at the top of the first.
        $double = & $heights 0, 0.3
        ($double | Measure-Object -Maximum).Maximum | Should -Be 9
        $double[-1] | Should -Be 0
        # A third key does nothing in the air.
        $triple = & $heights 0, 0.3, 0.6
        ($triple | Measure-Object -Maximum).Maximum | Should -Be 9
        # A key that comes at once after the first is the first key again, as a keyboard sends it for a
        # key that is held: it is not a second jump.
        $held = & $heights 0, 0.05, 0.1
        ($held | Measure-Object -Maximum).Maximum | Should -Be 5
        # The two jumps end after 1.08 seconds. A key a moment before that is a jump when the runner has
        # landed; a key that is earlier than that is nothing.
        $early = & $heights 0, 0.3, 1.0
        ($early[22..33] | Measure-Object -Maximum).Maximum | Should -Be 5
        $r.AdvanceGame(1)
        $tooEarly = & $heights 0, 0.3, 0.9
        ($tooEarly[22..39] | Measure-Object -Maximum).Maximum | Should -Be 0
        $r.Close()
    }

    It 'Puts a run of passed tests on a platform, which the runner lands on, runs along and leaves' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # Six tests that passed one after the other: four or more are a platform, four rows up, with the coins on it.
        1..6 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $r.AdvanceGame(2)
        $screen = $r.GetPlainScreen(80, 24)
        $view = Get-GameView $screen
        $screen[$view.Ground - 4] | Should -Match '▀{20,}'
        # A coin is two cells wide and two rows high, and it turns: its face, and for a moment its edge.
        ([regex]::Matches($screen[$view.Ground - 6], '▜▛|▐▌')).Count | Should -BeGreaterThan 3
        ([regex]::Matches($screen[$view.Ground - 7], '▟▙|▐▌')).Count | Should -BeGreaterThan 3
        ([regex]::Matches(($screen[($view.Ground - 3)..($view.Ground - 1)] -join ''), '▟▙|▜▛|▐▌')).Count | Should -Be 0
        @(Get-GameCourse $r 'Coin' | Where-Object { $_.Y -eq 5 -and $_.Width -eq 2 -and $_.Height -eq 2 }).Count | Should -BeGreaterThan 3
        # The runner jumps when the platform starts just ahead, and stands on it.
        $slab = { $s = $r.GetPlainScreen(80, 24); $s[(Get-GameView $s).Ground - 4].PadRight(80).IndexOf('▀') }
        for ($i = 0; $i -lt 400 -and (& $slab) -gt 19; $i++) { $r.AdvanceGame(0.025) }
        (& $slab) | Should -BeIn (18..19)
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.6)
        $view = Get-GameView $r.GetPlainScreen(80, 24)
        $view.Height | Should -Be 4
        $view.Air | Should -BeFalse
        # It runs along and has the coins without a jump.
        for ($i = 0; $i -lt 200 -and $r.GameResult.Coins -lt 6; $i++) {
            (Get-GameView $r.GetPlainScreen(80, 24)).Height | Should -Be 4
            $r.AdvanceGame(0.05)
        }
        $r.GameResult.Coins | Should -Be 6
        # A jump from the platform is a jump from four rows up.
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.3)
        (Get-GameView $r.GetPlainScreen(80, 24)).Height | Should -BeIn (8..9)
        # With no more passed tests the platform ends, and the runner is on the ground again.
        $r.AdvanceGame(4)
        $view = Get-GameView $r.GetPlainScreen(80, 24)
        $view.Height | Should -Be 0
        ($r.GetPlainScreen(80, 24)[2..21] -join '') | Should -Not -Match '▀'
        $r.Close()
    }

    It 'Puts fewer than four passed tests in a row on the ground, and the fourth and those after it on a platform' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # One at a time, as a run gives them: nobody knows yet that a fourth follows.
        $rows = foreach ($n in 1..5) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            $r.AdvanceGame(1)
            @(Get-GameCourse $r 'Coin')[-1].Y
        }
        # The coin of a test on the ground is at the height of the runner; on the bridge it is four rows
        # higher; and the coin of the step up to the bridge is in the air between the two, where the jump goes.
        $rows | Should -Be @(1, 1, 1, 3, 5)
        # A test that fails does not end the bridge: its creature walks along it, and the next coin is on it too.
        Complete-GameTest $r 'F.1' -Severity 'Low'
        $r.AdvanceGame(0.5)
        Complete-GameTest $r 'P.6' -Result 'Passed'
        $r.AdvanceGame(1)
        @(Get-GameCourse $r 'Biter')[0].Y | Should -Be 4
        $last = @(Get-GameCourse $r 'Coin')[-1]
        $last.Id | Should -Be 'P.6'
        $last.Y | Should -Be 5
        $r.Close()
    }

    It 'Has a second, higher level of platforms on a screen that is tall enough, a jump above the first' {
        $t = New-GameDashboard -Width 100 -Height 30 -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # Six coins on the lower level, and the next six on the higher one.
        1..6 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $r.AdvanceGame(1.5)
        7..12 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $r.AdvanceGame(1.5)
        $screen = $r.GetPlainScreen(100, 30)
        $ground = (Get-GameView $screen).Ground
        $screen[$ground - 4] | Should -Match '▀{20,}'
        $screen[$ground - 8] | Should -Match '▀{10,}'
        # The higher one starts over the end of the lower one.
        ($screen[$ground - 8].IndexOf('▀') - $screen[$ground - 4].TrimEnd().Length) | Should -BeIn (-5..-3)
        # A player who jumps where a platform starts has all twelve, and was eight rows up.
        $highest = 0
        for ($i = 0; $i -lt 16 -and $r.GameResult.Coins -lt 12; $i++) {
            Invoke-GameCourse $r -Seconds 0.5 -Width 100 -Height 30
            $view = Get-GameView $r.GetPlainScreen(100, 30)
            if (-not $view.Air) { $highest = [math]::Max($highest, $view.Height) }
        }
        $r.GameResult.Coins | Should -Be 12
        $highest | Should -Be 8
        $r.Close()

        # A screen of 24 rows has the lower level only.
        $t = New-GameDashboard -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..6 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $r.AdvanceGame(1.5)
        7..12 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Invoke-GameCourse $r -Seconds 8
        $r.GameResult.Coins | Should -Be 12
        $r.Close()
    }

    It 'Makes a failed test a creature of its severity: <Severity> is a <Kind>, <Rows> rows high' -ForEach @(
        @{ Severity = 'Critical'; Kind = 'Giant'; Rows = 5; Wide = 7; Walks = 2; Colour = '1;35'; From = 20; Twice = $true; Top = '▙ ▟█▙ ▟' }
        @{ Severity = 'High'; Kind = 'Brute'; Rows = 3; Wide = 5; Walks = 6; Colour = '38;5;208'; From = 14; Twice = $false; Top = ' ▟██▙' }
        @{ Severity = 'Medium'; Kind = 'Biter'; Rows = 2; Wide = 5; Walks = 3; Colour = '33'; From = 14; Twice = $false; Top = '▗▟▀█▙' }
        @{ Severity = 'Low'; Kind = 'Biter'; Rows = 2; Wide = 5; Walks = 3; Colour = '38;5;245'; From = 14; Twice = $false; Top = '▗▟▀█▙' }
        @{ Severity = 'Info'; Kind = 'Biter'; Rows = 2; Wide = 5; Walks = 3; Colour = '38;5;245'; From = 14; Twice = $false; Top = '▗▟▀█▙' }
    ) {
        $t = New-GameDashboard
        $r = $t.Renderer
        Complete-GameTest $r 'MT.1050' -Severity $Severity -Title 'Apps with a path to Global Administrator'
        Send-GameText $r 'dead'
        $r.AdvanceGame(0.5)
        $creature = @(Get-GameCourse $r $Kind)
        $creature.Count | Should -Be 1
        $creature[0].Width | Should -Be $Wide
        $creature[0].Height | Should -Be $Rows
        $creature[0].Y | Should -Be 0
        $creature[0].Count | Should -Be 1
        $creature[0].Id | Should -Be 'MT.1050'
        # It stands on the ground, with the ID of the test above it.
        $screen = $r.GetPlainScreen(80, 24)
        $view = Get-GameView $screen
        $at = $screen[$view.Ground - $Rows].IndexOf($Top.Trim()) - ($Top.Length - $Top.TrimStart().Length)
        $at | Should -BeGreaterThan ($view.X + 5)
        $body = @(($view.Ground - $Rows)..($view.Ground - 1) | ForEach-Object { $screen[$_].PadRight(80).Substring($at, $Wide) })
        $body | ForEach-Object { $_.Trim() | Should -Not -BeNullOrEmpty }
        $screen[$view.Ground - $Rows - 1].PadRight(80).Substring($at - 2, $Wide + 4).Trim() | Should -Be 'MT.1050'
        $screen[$view.Ground - $Rows - 2].PadRight(80).Substring($at, $Wide).Trim() | Should -BeNullOrEmpty
        # It walks towards the runner: it comes nearer faster than the ground goes by, a brute the fastest.
        $before = $creature[0].X
        $r.AdvanceGame(1)
        [math]::Round($before - @(Get-GameCourse $r $Kind)[0].X, 1) | Should -Be (22 + $Walks)
        # The giant is announced when it comes on the course.
        if ($Kind -eq 'Giant') { $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ! Ahead, and it takes two jumps: MT\.1050 Apps ' }

        # A runner that comes down on it stomps it: the points of half a test, and the runner bounces.
        $null = $r.TakeGameSounds()
        Invoke-GameStomp $r -From $From -Twice:$Twice
        $result = $r.GameResult
        $result.Stomps | Should -Be 1
        $result.Hits | Should -Be 0
        $result.Score | Should -Be 500
        $screen = $r.GetPlainScreen(80, 24)
        (Get-GameTopLine $screen) | Should -Match (Get-GameHud -Score 500 -Streak 1)
        $screen[22] | Should -Match '^ ✓ Stomped MT\.1050 Apps \S+ \+500 +in the game only: 1 still needs you for real$'
        $sounds = $r.TakeGameSounds()
        @($sounds | Where-Object { $_ -eq 'Stomp' }).Count | Should -Be 1
        $sounds | Should -Not -Contain 'Hit'
        # The failed test is still a failed test of the run.
        $r.Failed | Should -Be 1
        $r.Close()

        # The creature has the colour of the severity.
        $t = New-GameDashboard
        Complete-GameTest $t.Renderer 'MT.1050' -Severity $Severity
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.AdvanceGame(0.5)
        $t.Renderer.Stop()
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;${Colour}m" + $Top.Trim().Substring(0, 1)))
        $t.Renderer.Close()
    }

    It 'Has a <Kind> open its mouth, for long enough to answer it, and lunge at a runner that is still on its floor' -ForEach @(
        @{ Kind = 'Biter'; Severity = 'Low'; Lunge = 30; Open = '▛▀▀█▙'; Shut = '▗▟▀█▙' }
        @{ Kind = 'Brute'; Severity = 'High'; Lunge = 35; Open = '▀█▀██'; Shut = '▄█▀██' }
    ) {
        $t = New-GameDashboard
        $r = $t.Renderer
        Complete-GameTest $r 'F.1' -Severity $Severity -Title 'A failed test'
        Send-GameText $r 'dead'
        $null = $r.TakeGameSounds()
        # It walks, its mouth shut, until the runner is near.
        $states = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt 400 -and $r.GameResult.Hits -eq 0; $i++) {
            $r.AdvanceGame(0.025)
            $creature = @(Get-GameCourse $r $Kind)[0]
            $states.Add([pscustomobject]@{ State = $creature.State; X = $creature.X; Screen = $r.GetPlainScreen(80, 24) -join "`n" })
        }
        $opens = @($states | Where-Object State -EQ 'opens')
        $lunges = @($states | Where-Object State -EQ 'lunges')
        $walks = @($states | Where-Object State -EQ 'walks')
        # The mouth opens when the world brings the runner to it in three quarters of a second: 16.5 cells
        # at the speed of a game that began.
        $opens[0].X | Should -BeLessOrEqual 16.5
        $opens[0].X | Should -BeGreaterThan 15.4
        ($walks | Measure-Object X -Minimum).Minimum | Should -BeGreaterThan 16.5
        $walks | Where-Object X -LT 50 | ForEach-Object { $_.Screen | Should -Match $Shut; $_.Screen | Should -Not -Match $Open }
        $opens | ForEach-Object { $_.Screen | Should -Match $Open }
        # It stands with its mouth open for 0.45 seconds: the ground goes by, and it does not walk.
        $opens.Count | Should -BeIn (18..19)
        [math]::Round(($opens[0].X - $opens[-1].X) / ($opens.Count - 1) * 40) | Should -Be 22
        # Then it lunges, and the runner that did not jump is bitten.
        $lunges.Count | Should -BeGreaterThan 1
        [math]::Round(($lunges[0].X - $lunges[1].X) * 40) | Should -Be (22 + $Lunge)
        $r.GameResult.Hits | Should -Be 1
        $r.TakeGameSounds() | Should -Be @('Snap', 'Hit')
        $screen = $r.GetPlainScreen(80, 24)
        $screen[22] | Should -Match '^ ✗ Bitten by F\.1 A failed test +in the game only: 1 still needs you for real$'
        (Get-GameTopLine $screen) | Should -Match (Get-GameHud -Hearts 2)
        $r.Close()

        # A runner that is in the air by then is not lunged at: the creature walks on, its mouth shut.
        $t = New-GameDashboard
        $r = $t.Renderer
        Complete-GameTest $r 'F.1' -Severity $Severity
        Send-GameText $r 'dead'
        $i = 0
        do { $r.AdvanceGame(0.025) } while ($i++ -lt 400 -and @(Get-GameCourse $r $Kind)[0].X -gt 19)
        $null = $r.TakeGameSounds()
        Send-GameKey $r Spacebar
        foreach ($step in 1..20) {
            $r.AdvanceGame(0.025)
            @(Get-GameCourse $r $Kind)[0].State | Should -Be 'walks'
        }
        $r.TakeGameSounds() | Should -Be @('Jump')
        $r.Close()

        # The open mouth can be answered: a jump at any moment of the next third of a second and more
        # is over it in time, and comes down on its head.
        foreach ($late in 0.05, 0.2, 0.3, 0.35) {
            $t = New-GameDashboard
            $r = $t.Renderer
            Complete-GameTest $r 'F.1' -Severity $Severity
            Send-GameText $r 'dead'
            $i = 0
            do { $r.AdvanceGame(0.025) } while ($i++ -lt 400 -and @(Get-GameCourse $r $Kind)[0].State -eq 'walks')
            $r.AdvanceGame($late)
            Send-GameKey $r Spacebar
            $r.AdvanceGame(2)
            $r.GameResult.Hits | Should -Be 0
            $r.GameResult.Stomps | Should -Be 1
            $r.Close()
        }
    }

    It 'Counts a hit when the runner runs into a creature, and not when it comes down on it' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Complete-GameTest $r 'F.1' -Severity 'Critical' -Title 'A failed test'
        Complete-GameTest $r 'P.1' -Result 'Passed'
        Send-GameText $r 'dead'
        $null = $r.TakeGameSounds()
        # Nobody jumps: the creature walks into the runner.
        Wait-GameHit $r | Should -BeTrue
        $result = $r.GameResult
        $result.Hits | Should -Be 1
        $result.Stomps | Should -Be 0
        $result.Score | Should -Be 0
        $r.TakeGameSounds() | Should -Be @('Hit')
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ✗ Hit by F\.1 A failed test +in the game only: 1 still needs you for real$'
        # The runner stumbles for a second and a half: its head goes down and up, it is not hit again, and
        # it collects nothing. The coin of the test that passed right after goes by.
        $r.AdvanceGame(0.6)
        $heads = @(for ($i = 0; $i -lt 14; $i++) {
            $r.AdvanceGame(0.05)
            $screen = $r.GetPlainScreen(80, 24)
            $view = Get-GameView $screen
            $screen[$view.Ground - 3].PadRight(20).Substring($view.X, 5)
        })
        # (The coin is drawn where it goes by, behind the runner.)
        $heads | Should -Contain ' ▗▄▖ '
        $heads | Should -Contain ' ▟█▙ '
        $r.AdvanceGame(2)
        $result = $r.GameResult
        $result.Hits | Should -Be 1
        $result.Coins | Should -Be 0
        (@(1..40 | ForEach-Object { $r.AdvanceGame(0.05); $s = $r.GetPlainScreen(80, 24); $s[(Get-GameView $s).Ground - 3].PadRight(20).Substring(11, 5) }) | Select-Object -Unique) | Should -Be ' ▟█▙ '
        # After that it collects again.
        Complete-GameTest $r 'P.2' -Result 'Passed'
        $r.AdvanceGame(5)
        $r.GameResult.Coins | Should -Be 1
        $r.Close()

        # A jump that is too low for the giant is a hit as well: it takes two.
        $t = New-GameDashboard
        $r = $t.Renderer
        Complete-GameTest $r 'F.1' -Severity 'Critical'
        Send-GameText $r 'dead'
        Invoke-GameStomp $r -From 12
        $r.GameResult.Hits | Should -Be 1
        $r.GameResult.Stomps | Should -Be 0
        $r.Close()
    }

    It 'Collects a passed test as a coin: the points of a whole test, and one more in the streak' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ Jump on the failed tests\. +in the game only: nothing needs you for real$'
        $null = $r.TakeGameSounds()
        foreach ($n in 1..3) {
            Complete-GameTest $r "P.$n" -Result 'Passed' -Title "Passed test $n"
            $r.AdvanceGame(0.3)
            # The coin is on the ground ahead, at the height of the runner.
            $screen = $r.GetPlainScreen(80, 24)
            $screen[(Get-GameView $screen).Ground - 3] | Should -Match '▟▙|▐▌'
            $screen[(Get-GameView $screen).Ground - 2] | Should -Match '▜▛|▐▌'
            $r.AdvanceGame(4)
            $result = $r.GameResult
            $result.Coins | Should -Be $n
            $result.BestStreak | Should -Be $n
            $result.Score | Should -Be (1000 * $n)
            $screen = $r.GetPlainScreen(80, 24)
            (Get-GameTopLine $screen) | Should -Match (Get-GameHud -Score ('{0:N0}' -f (1000 * $n)) -Streak $n)
            $screen[22] | Should -Match "^ ● Collected P\.$n Passed \S+ \+1000 "
            ($screen[2..21] -join '') | Should -Not -Match '▟▙|▜▛|▐▌'
        }
        $r.TakeGameSounds() | Should -Be @('Coin', 'Coin', 'Coin')
        # A test that was skipped is not on the course, and is worth nothing.
        Complete-GameTest $r 'S.1' -Result 'Skipped'
        Complete-GameTest $r 'N.1' -Result 'NotRun'
        $r.AdvanceGame(5)
        @(Get-GameCourse $r).Count | Should -Be 1
        $r.GameResult.Score | Should -Be 3000
        # A coin is collected by a runner that jumps over it as well.
        Complete-GameTest $r 'J.1' -Result 'Passed'
        $i = 0
        do { $r.AdvanceGame(0.025) } while ($i++ -lt 400 -and @(Get-GameCourse $r 'Coin')[0].X -gt 6)
        Send-GameKey $r Spacebar
        $r.AdvanceGame(1.5)
        $r.GameResult.Coins | Should -Be 4
        $r.Close()
    }

    It 'Goes faster with the streak, up to 1.6 times and no further' {
        $t = New-GameDashboard -Total 5000
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # 22 cells a second at the start.
        (Measure-GameGround $r -Seconds 1) | Should -BeIn (21..23)
        # A streak of 30 and more is the fastest: 35 cells a second.
        1..400 | ForEach-Object { $r.ItemFinished('Passed') }
        Invoke-GameCourse $r -Seconds 12
        $r.GameResult.BestStreak | Should -BeGreaterThan 200
        (Measure-GameGround $r -Seconds 1) | Should -BeIn (34..36)
        1..400 | ForEach-Object { $r.ItemFinished('Passed') }
        Invoke-GameCourse $r -Seconds 12
        $r.GameResult.BestStreak | Should -BeGreaterThan 500
        (Measure-GameGround $r -Seconds 1) | Should -BeIn (34..36)
        # A hit ends the streak, and the world slows down again.
        Complete-GameTest $r 'F.1'
        for ($i = 0; $i -lt 400 -and $r.GameResult.Hits -eq 0; $i++) { $r.AdvanceGame(0.025) }
        $r.GetPlainScreen(80, 24)[0] | Should -Match '♥ ♥ ♡  SCORE [\d,]+  STREAK 0 '
        $r.AdvanceGame(3)
        (Measure-GameGround $r -Seconds 1) | Should -BeIn (21..23)
        $r.Close()
    }

    It 'Makes one piece of several results when they come faster than they can be played' {
        $t = New-GameDashboard -Total 400
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # Eighty passed tests at once: large coins that say how many tests each stands for.
        1..80 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $r.AdvanceGame(1.5)
        $screen = $r.GetPlainScreen(80, 24) -join "`n"
        # A coin of several tests has the ID of the first of them over it, and how many more it is.
        $screen | Should -Match 'P\.1 \+9'
        $screen | Should -Match '▟█▙'
        $null = $r.TakeGameSounds()
        # The ticker says how many tests a coin was.
        $said = $false
        for ($i = 0; $i -lt 20; $i++) {
            Invoke-GameCourse $r -Seconds 0.5
            if ($r.GetPlainScreen(80, 24)[22] -match '^ ● Collected \d+ passed tests \+\d+ ') { $said = $true }
        }
        $said | Should -BeTrue
        # All eighty are collected, with a handful of coins.
        $r.GameResult.Coins | Should -Be 80
        $r.GameResult.Score | Should -Be 1800
        @($r.TakeGameSounds() | Where-Object { $_ -eq 'Coin' }).Count | Should -BeIn (8..30)

        # Thirty failed tests at once: wide creatures, each with the ID of the most severe of its tests.
        $r.AdvanceGame(3)
        $severities = 'Low', 'Medium', 'Critical', 'High'
        1..30 | ForEach-Object { Complete-GameTest $r "F.$_" -Severity $severities[($_ - 1) % 4] }
        $r.AdvanceGame(0.6)
        $screen = $r.GetPlainScreen(80, 24)
        $view = Get-GameView $screen
        # The first four are one creature: the giant, for the Critical one among them, with its ID, and wider.
        ($screen -join "`n") | Should -Match 'F\.3 \+3'
        $screen[$view.Ground - 5] | Should -Match '▙ ▟█▙ ▟█▙'
        $giant = @(Get-GameCourse $r 'Giant')[0]
        $giant.Width | Should -Be 9
        $giant.Count | Should -Be 4
        # (After a streak of eighty the world goes by at its fastest, so the jump is from further away.)
        Invoke-GameStomp $r -From 33 -Twice
        $r.GameResult.Stomps | Should -Be 4
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ✓ Stomped F\.3 and 3 more \+\d+ '
        $r.Close()
    }

    It 'Gives a game that starts in the middle of a run, or comes back to the screen, what it missed in a few pieces' {
        $t = New-GameDashboard -Total 300
        $r = $t.Renderer
        1..60 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        $r.AdvanceGame(1.5)
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Match 'P\.1 \+7'
        Invoke-GameCourse $r -Seconds 10
        $r.GameResult.Coins | Should -Be 60
        # Off screen the game stands still, and the run goes on.
        Send-GameKey $r Escape
        1..40 | ForEach-Object { Complete-GameTest $r "Q.$_" -Result 'Passed' }
        $r.AdvanceGame(5)
        $r.GameResult.Coins | Should -Be 60
        Send-GameText $r 'dead'
        $r.AdvanceGame(1.5)
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Match 'Q\.1 \+4'
        Invoke-GameCourse $r -Seconds 10
        $r.GameResult.Coins | Should -Be 100
        # What comes one at a time after that is one coin for a test again.
        $r.AdvanceGame(3)
        Complete-GameTest $r 'F.1' -Severity 'Low'
        Complete-GameTest $r 'R.1' -Result 'Passed'
        $r.AdvanceGame(1.5)
        $screen = $r.GetPlainScreen(80, 24)
        ($screen[2..21] -join '') | Should -Match '▟▙|▐▌'
        ($screen[2..21] -join '') | Should -Not -Match '×'
        $r.Close()
    }

    It 'Scores a share of 10,000: all of it for every test of a run collected, whatever their number' {
        # Three tests, all passed, all collected.
        $t = New-GameDashboard -Total 3
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $r.GameScore | Should -Be 0
        1..3 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(4) }
        $r.GameScore | Should -Be 10000
        $r.GetPlainScreen(80, 24)[0] | Should -Match ' SCORE 10,000 '
        # More results than the run said it has: never more than 10,000.
        1..3 | ForEach-Object { Complete-GameTest $r "X.$_" -Result 'Passed'; Invoke-GameCourse $r -Seconds 4 }
        $r.GameResult.Coins | Should -Be 6
        $r.GameScore | Should -Be 10000
        $r.Close()

        # Forty-seven tests, all passed, on platforms most of them.
        $t = New-GameDashboard -Total 47
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..47) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            Invoke-GameCourse $r -Seconds 0.5
        }
        Invoke-GameCourse $r -Seconds 6
        $result = $r.GameResult
        $result.Coins | Should -Be 47
        $result.Hits | Should -Be 0
        $result.BestStreak | Should -Be 47
        $result.Tests | Should -Be 47
        $result.Score | Should -Be 10000
        $r.Close()

        # What had not reached the runner when the tests stopped is not held against it: two tests of
        # four were collected, and the other two were still on their way. They are not in what the
        # score is a share of.
        $t = New-GameDashboard -Total 4
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..2 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(4) }
        $r.GameScore | Should -Be 5000
        1..2 | ForEach-Object { Complete-GameTest $r "L.$_" -Result 'Passed' }
        $r.GameScore | Should -Be 5000
        $r.Stop()
        $r.AdvanceGame(10)
        $r.GameScore | Should -Be 10000
        $r.GameResult.Coins | Should -Be 2
        $r.Close()

        # A coin that went by is not one of them: it reached the runner, which did not take it.
        $t = New-GameDashboard -Total 4
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..2 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(4) }
        # (On the ground a coin is collected by running through it: this one is jumped over twice, out of reach.)
        Complete-GameTest $r 'M.1' -Result 'Failed' -Severity 'Low'
        $r.AdvanceGame(8)
        Complete-GameTest $r 'L.1' -Result 'Passed'
        $r.Stop()
        $r.GameResult.Stomps | Should -Be 0
        # Two of the three that reached it: the failed test walked past, and the last one is left out.
        $r.GameScore | Should -Be ([math]::Floor(10000 * 2000 / 3000))
        $r.Close()

        # Not for a game that stood still: one that is paused when the tests stop, one that was put away,
        # and one that is over. What waited for the player is the player's.
        foreach ($how in 'paused', 'away', 'help') {
            $t = New-GameDashboard -Total 4
            $r = $t.Renderer
            Send-GameText $r 'dead'
            1..2 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(4) }
            switch ($how) { 'paused' { Send-GameText $r 'p' } 'away' { Send-GameKey $r Escape } 'help' { Send-GameText $r '?' } }
            1..2 | ForEach-Object { Complete-GameTest $r "L.$_" -Result 'Passed' }
            $r.Stop()
            $r.GameScore | Should -Be 5000
            $r.Close()
        }

        # And not what came while it stood still, when it runs again and the tests stop before it has
        # caught up: of four that wait, one came after the pause, and only that one is left out.
        $t = New-GameDashboard -Total 6
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..2 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $r.AdvanceGame(4) }
        Send-GameText $r 'p'
        1..3 | ForEach-Object { Complete-GameTest $r "W.$_" -Result 'Passed' }
        Send-GameText $r 'p'
        Complete-GameTest $r 'L.1' -Result 'Passed'
        $r.Stop()
        $r.GameResult.Coins | Should -Be 2
        $r.GameScore | Should -Be ([math]::Floor(10000 * 2 / 5))
        $r.Close()
    }

    It 'Scores a stomped failure as half a test, and less for a runner that was hit: the score rises with the tests that pass' {
        # Runs of four tests, played without a mistake: the more of them passed, the higher the score.
        $play = {
            param([string[]] $Results)
            $t = New-GameDashboard -Total $Results.Count
            $r = $t.Renderer
            Send-GameText $r 'dead'
            foreach ($result in $Results) {
                switch ($result) {
                    'Passed' { Complete-GameTest $r 'P' -Result 'Passed'; Invoke-GameCourse $r -Seconds 4 }
                    'Stomped' { Complete-GameTest $r 'F' -Severity 'Low'; Invoke-GameStomp $r; $r.AdvanceGame(2) }
                    'Hit' { Complete-GameTest $r 'F' -Severity 'Low'; $r.AdvanceGame(6) }
                    default { Complete-GameTest $r 'S' -Result 'Skipped'; $r.AdvanceGame(1) }
                }
            }
            $r.GameScore
            $r.Close()
        }
        $scores = @(
            (& $play 'Stomped', 'Stomped', 'Stomped', 'Stomped'), (& $play 'Passed', 'Stomped', 'Stomped', 'Stomped'), (& $play 'Passed', 'Passed', 'Stomped', 'Stomped'),
            (& $play 'Passed', 'Passed', 'Passed', 'Stomped'), (& $play 'Passed', 'Passed', 'Passed', 'Passed')
        )
        $scores | Should -Be @(5000, 6250, 7500, 8750, 10000)
        # A test that was skipped is in the count of the run, and earns nothing.
        (& $play 'Passed', 'Passed', 'Passed', 'Skipped') | Should -Be 7500
        # A hit takes the form of the runner: the next pick-ups are worth six tenths, and a twenty-fifth
        # more with each, until the tenth is worth all again.
        (& $play 'Hit', 'Passed', 'Passed', 'Passed') | Should -Be ([int]((600 + 640 + 680) * 10000 / 4000))
        (& $play 'Passed', 'Hit', 'Passed', 'Stomped') | Should -Be ([int]((1000 + 600 + 320) * 10000 / 4000))
        # Nothing collected is nothing.
        (& $play 'Hit', 'Hit', 'Skipped', 'Skipped') | Should -Be 0

        $t = New-GameDashboard -Total 12
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'F.0' -Severity 'Low'
        $r.AdvanceGame(6)
        foreach ($n in 1..12) {
            $before = $r.GameResult
            if ($n % 4 -eq 0) { Complete-GameTest $r "F.$n" -Severity 'Low'; Invoke-GameStomp $r; $r.AdvanceGame(1) }
            else { Complete-GameTest $r "P.$n" -Result 'Passed'; $r.AdvanceGame(4) }
            $r.GameResult.Hits | Should -Be 1
        }
        # Three coins, a stomp, three coins, a stomp, and then the form is whole: the tenth and eleventh coin are full.
        $r.GameResult.Coins | Should -Be 9
        $r.GameResult.Stomps | Should -Be 3
        $units = 600 + 640 + 680 + 360 + 760 + 800 + 840 + 440 + 920 + 960 + 1000 + 500
        $r.GameScore | Should -Be ([int][math]::Floor($units * 10000 / 12000))
        $r.Close()
    }

    It 'Shows the real run above the game: the progress, the counts, the bar and the counter behind the playfield' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 60
        $r = $t.Renderer
        1..5 | ForEach-Object { $r.ItemFinished('Passed') }
        1..4 | ForEach-Object { Complete-GameTest $r "F.$_" }
        $r.ItemFinished('Error')
        $r.ItemFinished('Skipped')
        $r.ItemFinished('Investigate')
        Send-GameText $r 'dead'
        $screen = $r.GetPlainScreen(165, 52)
        # (On a screen of this size the top is a band of five rows: the run is at its right, in two of them.)
        (Get-GameTopLine $screen) | Should -Match ' run 12/60  20%( +ETA \d+:\d\d)?  ✓ 5  ✗ 4  ! 1$'
        $screen[1] | Should -Match ' run 12/60  20%( +ETA \d+:\d\d)?$'
        $screen[1].Length | Should -Be 164
        $screen[2] | Should -Match '  ✓ 5  ✗ 4  ! 1$'
        $screen[2].Length | Should -Be 164
        # A fifth of the bar under the band is filled, and its end is the finish.
        $screen[5] | Should -Match '^ ━{31}─{125} FINISH$'
        ($screen -join "`n") | Should -Match 'tests completed'
        $screen[50] | Should -Match 'in the game only: 4 still need you for real$'
        $screen[51] | Should -Match '^ Space jump   Space again in the air: double jump   P pause +M sound on   \? help   Esc back to the dashboard $'
        $screen[51].Length | Should -Be 164
        # The counter is the number of the run in large digits, in the sky.
        $dots = { ([regex]::Matches(($r.GetPlainScreen(165, 52)[6..34] -join ''), '·')).Count }
        $before = & $dots
        $before | Should -BeGreaterThan 100
        # It follows the run while the game is played.
        1..8 | ForEach-Object { $r.ItemFinished('Passed') }
        $screen = $r.GetPlainScreen(165, 52)
        (Get-GameTopLine $screen) | Should -Match ' run 20/60  33%.*  ✓ 13  ✗ 4  ! 1$'
        & $dots | Should -Not -Be $before
        # In colour the digits are blocks in a dark grey, behind everything.
        $r.Stop()
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;38;5;236m") + '█+')
        $r.Close()
    }

    It 'Fits the game to the console (<Width>x<Height>): every row, and no row as wide as the console' -ForEach @(
        @{ Width = 80; Height = 24 }, @{ Width = 100; Height = 30 }, @{ Width = 124; Height = 38 }, @{ Width = 165; Height = 52 }, @{ Width = 240; Height = 70 }
    ) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 2000
        $r = $t.Renderer
        1..40 | ForEach-Object { Complete-GameTest $r "CISA.MS.SHAREPOINT.$_.1" -Title ('A very long title ' * 12) }
        1..1200 | ForEach-Object { $r.ItemFinished('Passed') }
        Send-GameText $r 'dead'
        foreach ($moment in 1..30) {
            1..3 | ForEach-Object { Complete-GameTest $r "CISA.MS.SHAREPOINT.$moment.$_" -Result $(if ($_ -eq 2) { 'Failed' } else { 'Passed' }) -Severity 'Critical' -Title ('A very long title ' * 12) }
            $r.AdvanceGame(0.35)
            if ($moment % 3 -eq 0) { Send-GameKey $r Spacebar }
            $screen = $r.GetPlainScreen($Width, $Height)
            $screen.Count | Should -Be $Height
            foreach ($line in $screen) { $line.Length | Should -BeLessThan $Width }
            (Get-GameTopLine $screen) | Should -Match '^ (MAESTER )?RUN  [♥♡]( [♥♡]){2}  SCORE '
            (Get-GameTopLine $screen) | Should -Match ('✓ {0}  ✗ {1}  ! 0$' -f (1200 + 2 * $moment), (40 + $moment))
            @($screen | Where-Object { $_ -match ' FINISH$' }).Count | Should -Be 1
        }
        $r.Close()
    }

    It 'Pauses on P, and goes on with P' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        1..3 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        $r.AdvanceGame(1)
        Send-GameText $r 'P'
        $paused = $r.GetPlainScreen(165, 52)
        ($paused -join "`n") | Should -Match 'PAUSED'
        Send-GameKey $r Spacebar
        $r.AdvanceGame(3)
        $r.GetPlainScreen(165, 52) | Should -Be $paused
        Send-GameText $r 'p'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Not -Match 'PAUSED'
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.3)
        (Get-GameView $r.GetPlainScreen(165, 52)).Air | Should -BeTrue
        $r.Close()
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

    It 'Draws the game with ASCII characters only when Unicode is off (<Width>x<Height>)' -ForEach @(@{ Width = 165; Height = 52 }, @{ Width = 80; Height = 24 }) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 400 -Ascii -Extras
        $r = $t.Renderer
        1..60 | ForEach-Object { Complete-GameTest $r "CISA.MS.SHAREPOINT.$_.1" -Result $(if ($_ % 3) { 'Passed' } else { 'Failed' }) -Severity @('Critical', 'High', 'Low')[$_ % 2] -Title 'A title' }
        Send-GameText $r 'dead'
        $ascii = '^[\x20-\x7E]*$'
        $seen = [System.Text.StringBuilder]::new()
        # While it is played, with everything that can be on the course and with what the dice add; when a
        # game is over, and the next one is started; paused; and when the tests stop.
        $results = 'Failed', 'Passed', 'Error', 'Passed', 'Investigate', 'Passed'
        $severities = 'Critical', 'High', 'Medium', 'Low'
        for ($i = 0; $i -lt 900; $i++) {
            if ($i % 12 -eq 0) { Complete-GameTest $r "MT.$i" -Result $results[($i / 12) % 6] -Severity $severities[($i / 72) % 4] -Title 'A title' }
            if ($i % 17 -eq 0) { Send-GameKey $r Spacebar }
            if ($i % 60 -eq 59) { Send-GameKey $r Enter }
            $r.AdvanceGame(0.05)
            $screen = $r.GetPlainScreen($Width, $Height)
            foreach ($line in $screen) { $line | Should -Match $ascii }
            $null = $seen.Append(($screen -join "`n"))
        }
        $all = $seen.ToString()
        $all | Should -Match ' RUN  \* \* \*  SCORE \d+  STREAK \d'
        $all | Should -Match ' RUN  \* \. \.  SCORE '
        $all | Should -Match ' RUN  \. \. \.  SCORE '
        # The runner, a coin and its edge, a coin of several tests, and a platform.
        $all | Should -Match ([regex]::Escape('[###]'))
        $all | Should -Match ' /\\ '
        $all | Should -Match ' \|\| '
        $all | Should -Match 'CISA\.MS\.\S+ \+\d+'
        $all | Should -Match '(\+ Stomped|o Collected|x Hit by|x Bitten by) '
        $all | Should -Match 'Space jump'
        # The card of a game that is over, and its keys.
        $all | Should -Match 'GAME OVER'
        $all | Should -Match 'Enter  play again     Esc  dashboard'
        $all | Should -Match '\n Enter play again +M sound on   Esc back to the dashboard'
        Send-GameText $r 'p'
        foreach ($line in $r.GetPlainScreen($Width, $Height)) { $line | Should -Match $ascii }
        Send-GameText $r 'p'
        $r.Stop()
        $card = $r.GetPlainScreen($Width, $Height)
        ($card -join "`n") | Should -Match 'RUN COMPLETE'
        ($card -join "`n") | Should -Match 'the best of \d+ games'
        foreach ($line in $card) { $line | Should -Match $ascii }
        # What is written to the console is ASCII as well, but for the escape character of the colours.
        $t.Writer.ToString() | Should -Match '^[\x20-\x7E\x1b\r\n]*$'
        $r.Close()

        # A run of passed tests: a platform, and the coins on it.
        $t = New-GameDashboard -Width $Width -Height $Height -Ascii
        Send-GameText $t.Renderer 'dead'
        1..6 | ForEach-Object { Complete-GameTest $t.Renderer "P.$_" -Result 'Passed' }
        $t.Renderer.AdvanceGame(2.5)
        $screen = $t.Renderer.GetPlainScreen($Width, $Height)
        foreach ($line in $screen) { $line | Should -Match $ascii }
        ($screen -join "`n") | Should -Match '={20,}'
        ($screen -join "`n") | Should -Match '(/\\|\|\|) +(/\\|\|\|) +(/\\|\|\|) '
        $t.Renderer.Close()

        # Everything that can be in the way, each as it is drawn: a biter with its mouth shut and open, a
        # brute, the giant, a plant in its pot and up, a bird with its wings up and down, and a walker.
        $shapes = {
            param([string] $Result, [string] $Severity, [double] $Seconds, [switch] $Extras)
            $t = New-GameDashboard -Width $Width -Height $Height -Ascii -Extras:$Extras
            if ($Result) { Complete-GameTest $t.Renderer 'T.1' -Result $Result -Severity $Severity }
            Send-GameText $t.Renderer 'dead'
            $drawn = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt $Seconds * 20; $i++) {
                $t.Renderer.AdvanceGame(0.05)
                # (A game that is over is started again, so that the course goes on.)
                Send-GameKey $t.Renderer Enter
                $screen = $t.Renderer.GetPlainScreen($Width, $Height)
                foreach ($line in $screen) { $line | Should -Match $ascii }
                $null = $drawn.Append(($screen -join "`n"))
            }
            $t.Renderer.Close()
            $drawn.ToString()
        }
        $biter = & $shapes 'Failed' 'Low' 8
        $biter | Should -Match ([regex]::Escape('=(oo)') + '\n.* /\\/\\')
        $biter | Should -Match ([regex]::Escape('\(oo)') + '\n.*//\\/\\')
        (& $shapes 'Failed' 'High' 3) | Should -Match (' \.--\.\n.*' + [regex]::Escape('=|oo|'))
        (& $shapes 'Failed' 'Critical' 3) | Should -Match ([regex]::Escape('\ ^^^ /') + '\n.*' + [regex]::Escape('|-----|') + '\n.*' + [regex]::Escape('|O   O|'))
        $plant = & $shapes 'Error' 'High' 6
        $plant | Should -Match ('T\.1\n.*' + [regex]::Escape('\V/') + '\n.*' + [regex]::Escape('\_/'))
        $plant | Should -Match ([regex]::Escape('(Y)') + '\n.*' + [regex]::Escape('\_/'))
        $bird = & $shapes 'Investigate' 'High' 3
        $bird | Should -Match ('T\.1\n.*' + [regex]::Escape('\   /') + '\n.* ' + [regex]::Escape('\v/'))
        $bird | Should -Match (' /\^\\ *\n.*' + [regex]::Escape('/   \'))
        (& $shapes $null $null 30 -Extras) | Should -Match ([regex]::Escape('(")') + '\n.*(/ \\|\| \|)')
    }

    It 'Writes no colour for the game when Ansi is off' {
        $t = New-GameDashboard -NoColor
        $r = $t.Renderer
        1..6 | ForEach-Object { Complete-GameTest $r "F.$_" }
        1..30 | ForEach-Object { $r.ItemFinished('Passed') }
        Send-GameText $r 'dead'
        $r.AdvanceGame(2)
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.1)
        $r.Stop()
        $out = $t.Writer.ToString()
        $out | Should -Match 'MAESTER RUN'
        $out | Should -Not -Match "$esc\[[\d;]*m"
        $r.Close()
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

    It 'Makes a test that ended in an error a plant in a pot with its ID, which comes up and goes down' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'E.1' -Result 'Error' -Title 'A test that broke'
        $r.AdvanceGame(0.5)
        $plant = @(Get-GameCourse $r 'Plant')
        $plant.Count | Should -Be 1
        $plant[0].Id | Should -Be 'E.1'
        $plant[0].Width | Should -Be 3
        $plant[0].Y | Should -Be 0
        $plant[0].Count | Should -Be 0
        # It is drawn in its pot, with the ID over it: the pot alone while it is down.
        $drawn = {
            $screen = $r.GetPlainScreen(165, 52)
            $view = Get-GameView $screen
            $at = $screen[$view.Ground - 1].IndexOf('▜█▛')
            [pscustomobject]@{ Name = $screen[$view.Ground - 3].PadRight(165).Substring($at - 2, 7).Trim(); Head = $screen[$view.Ground - 2].PadRight(165).Substring($at, 3) }
        }
        # One round takes 3.2 seconds: it is its pot alone for 1.2 of them, up for 1.5, and on its way
        # between the two for the rest. It stands where it is: it comes nearer as the ground goes by.
        $before = $plant[0].X
        $heads = @{}
        $heights = @(for ($i = 0; $i -lt 64; $i++) {
            $r.AdvanceGame(0.05)
            $height = @(Get-GameCourse $r 'Plant')[0].Height
            $now = & $drawn
            $now.Name | Should -Be 'E.1'
            $heads[$now.Head] = $height
            $height
        })
        [math]::Round($before - @(Get-GameCourse $r 'Plant')[0].X) | Should -Be 70
        @($heights | Where-Object { $_ -eq 1 }).Count | Should -BeIn (23..25)
        @($heights | Where-Object { $_ -eq 2 }).Count | Should -BeIn (29..31)
        @($heights | Where-Object { $_ -gt 1 -and $_ -lt 2 }).Count | Should -BeIn (9..11)
        ($heads.Keys | Sort-Object) | Should -Be @('   ', '▐█▌', '▗▄▖', '▚█▞')
        $heads['   '] | Should -Be 1
        $heads['▐█▌'] | Should -Be 2
        $heads['▚█▞'] | Should -Be 2
        # The plant of an error is red in its pot, and it earns nothing: an error is not in the score.
        $r.Stop()
        $frame = $t.Writer.ToString()
        $frame = $frame.Substring($frame.LastIndexOf("$esc[H"))
        $frame | Should -Match ([regex]::Escape("$esc[0;38;5;130m▜█▛"))
        $frame | Should -Match ([regex]::Escape("$esc[0;38;5;203m") + '(▐█▌|▗▄▖|▚█▞)')
        $r.Errors | Should -Be 1
        $r.GameScore | Should -Be 0
        $r.Close()
    }

    It 'Has a plant in the way while it is up and not while it is down: it is jumped over, and never stomped' {
        # A runner that runs on is hit by a plant that is up when it is there, and not by one that is down.
        # A plant that is down does not come up when the runner is less than three quarters of a second from it.
        $pass = {
            param([int] $Seed, [double] $JumpFrom = -1)
            $t = New-GameDashboard -Seed $Seed
            $r = $t.Renderer
            Send-GameText $r 'dead'
            Complete-GameTest $r 'E.1' -Result 'Error' -Title 'A test that broke'
            $up = $false
            $near = $null
            $jumped = $false
            for ($i = 0; $i -lt 240; $i++) {
                $r.AdvanceGame(0.025)
                $plant = @(Get-GameCourse $r 'Plant')[0]
                if (-not $plant) { break }
                if (-not $jumped -and $plant.X -le $JumpFrom) { Send-GameKey $r Spacebar; $jumped = $true }
                # It is where the middle of the runner is, and up.
                if ($plant.X -lt -2 -and $plant.X -gt -6 -and $plant.Height -ge 1.5) { $up = $true }
                if ($plant.X -lt 16 -and $plant.X -gt -8) {
                    if ($near -eq 1) { $plant.Height | Should -Be 1 }
                    $near = $plant.Height
                }
            }
            $result = $r.GameResult
            $ticker = $r.GetPlainScreen(80, 24)[22]
            $r.Close()
            [pscustomobject]@{ Up = $up; Hits = $result.Hits; Stomps = $result.Stomps; Score = $result.Score; Ticker = $ticker }
        }
        $runs = @(1..10 | ForEach-Object { & $pass $_ })
        foreach ($run in $runs) {
            $run.Hits | Should -Be ([int]$run.Up)
            $run.Stomps | Should -Be 0
            $run.Score | Should -Be 0
            if ($run.Up) { $run.Ticker | Should -Match '^ ✗ Hit by E\.1 A test that broke ' }
        }
        # Both happen, with the dice of ten games.
        $up = @(1..10 | Where-Object { $runs[$_ - 1].Up })
        $up.Count | Should -BeIn (2..8)
        foreach ($seed in $up) {
            # A jump from six cells before it is over it.
            $over = & $pass $seed 6
            $over.Hits | Should -Be 0
            $over.Stomps | Should -Be 0
            # A jump from further away comes down on it: that is a hit as well. A plant is not stomped.
            $onto = & $pass $seed 10
            $onto.Hits | Should -Be 1
            $onto.Stomps | Should -Be 0
        }
    }

    It 'Makes a test to investigate a bird with its ID, which flies over the head of a runner on the ground' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'I.1' -Result 'Investigate' -Title 'A test to look at'
        $r.AdvanceGame(0.05)
        $bird = @(Get-GameCourse $r 'Bird')
        $bird.Count | Should -Be 1
        $bird[0].Id | Should -Be 'I.1'
        $bird[0].Width | Should -Be 5
        $bird[0].Height | Should -Be 2
        $bird[0].State | Should -Be 'flies'
        $bird[0].Count | Should -Be 0
        # It flies towards the runner, five rows up, and goes up and down half a row as it does.
        $before = $bird[0].X
        $rows = @(for ($i = 0; $i -lt 40; $i++) { $r.AdvanceGame(0.05); @(Get-GameCourse $r 'Bird')[0].Y })
        [math]::Round($before - @(Get-GameCourse $r 'Bird')[0].X) | Should -Be 54
        ($rows | Measure-Object -Minimum).Minimum | Should -BeIn (4.5, 4.51, 4.52, 4.53)
        ($rows | Measure-Object -Maximum).Maximum | Should -BeIn (5.47, 5.48, 5.49, 5.5)
        # Its wings go up and down, and its ID is over it.
        $wings = @{}
        foreach ($i in 1..12) {
            $r.AdvanceGame(0.05)
            $screen = $r.GetPlainScreen(165, 52)
            $row = @(2..49 | Where-Object { $screen[$_] -match '▙   ▟|▛   ▜' })[0]
            $top = if ($screen[$row] -match '▙   ▟') { $row } else { $row - 1 }
            $at = [regex]::Match($screen[$row], '▙   ▟|▛   ▜').Index
            $wings[$screen[$top].PadRight(165).Substring($at, 5) + '/' + $screen[$top + 1].PadRight(165).Substring($at, 5)] = $true
            $screen[$top - 1].PadRight(165).Substring($at, 5).Trim() | Should -Be 'I.1'
        }
        ($wings.Keys | Sort-Object) | Should -Be @(' ▟█▙ /▛   ▜', '▙   ▟/ ▜█▛ ')
        # A runner on the ground runs under it.
        $r.AdvanceGame(6)
        $r.GameResult.Hits | Should -Be 0
        @(Get-GameCourse $r 'Bird').Count | Should -Be 0
        # The bird of a test is of a colour of its own.
        Complete-GameTest $r 'I.2' -Result 'Investigate'
        $r.AdvanceGame(0.5)
        $r.Stop()
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;36m") + '[▙▟]')
        $r.Close()
    }

    It 'Counts a hit for a runner that jumps into a bird from below, and stomps a bird that the runner comes down on' {
        # A jump right under it: the head of the runner hits it.
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'I.1' -Result 'Investigate' -Title 'A test to look at'
        $i = 0
        do { $r.AdvanceGame(0.025) } while ($i++ -lt 400 -and @(Get-GameCourse $r 'Bird')[0].X -gt 4)
        $null = $r.TakeGameSounds()
        Send-GameKey $r Spacebar
        $r.AdvanceGame(1)
        $r.GameResult.Hits | Should -Be 1
        $r.GameResult.Stomps | Should -Be 0
        $r.TakeGameSounds() | Should -Be @('Jump', 'Hit')
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ✗ Hit by I\.1 A test to look at '
        $r.Close()

        # Two jumps take the runner over it, and it comes down on the bird: stomped, and the runner
        # bounces. A bird is worth no points; it counts for the streak.
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'I.1' -Result 'Investigate' -Title 'A test to look at'
        $i = 0
        do { $r.AdvanceGame(0.025) } while ($i++ -lt 400 -and @(Get-GameCourse $r 'Bird')[0].X -gt 19)
        $null = $r.TakeGameSounds()
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.325)
        Send-GameKey $r Spacebar
        $up = @(for ($i = 0; $i -lt 40 -and $r.GameResult.Stomps -eq 0; $i++) { $r.AdvanceGame(0.025); @(Get-GameCourse $r)[0].Up })
        $result = $r.GameResult
        $result.Stomps | Should -Be 1
        $result.Hits | Should -Be 0
        $result.Score | Should -Be 0
        $result.BestStreak | Should -Be 1
        # It came down, and goes up again.
        $up[-2] | Should -BeLessThan 0
        $up[-1] | Should -BeGreaterThan 15
        $r.TakeGameSounds() | Should -Be @('Jump', 'DoubleJump', 'Stomp')
        $screen = $r.GetPlainScreen(80, 24)
        $screen[22] | Should -Match '^ ✓ Stomped I\.1 A test to look at +in the game only: nothing needs you for real$'
        (Get-GameTopLine $screen) | Should -Match (Get-GameHud -Streak 1)
        # What is left of it is in the air for a moment.
        ($screen[2..21] -join "`n") | Should -Match '▘▗▝'
        $r.Close()
    }

    It 'Has a bird at the height of a runner on a platform: it hits the runner that stands, and is stomped by one that jumps' {
        $fly = {
            param([bool] $Jump)
            $t = New-GameDashboard
            $r = $t.Renderer
            Send-GameText $r 'dead'
            1..6 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
            Invoke-GameCourse $r -Seconds 2
            Complete-GameTest $r 'I.1' -Result 'Investigate' -Title 'A test to look at'
            Invoke-GameCourse $r -Seconds 1.5
            # The runner is on the platform, and the bird comes at it, a row over the platform.
            $bird = @(Get-GameCourse $r 'Bird')[0]
            $bird.State | Should -Be 'flies'
            $bird.Y | Should -BeGreaterOrEqual 4.5
            $bird.Y | Should -BeLessOrEqual 5.5
            @(Get-GameCourse $r)[0].Y | Should -Be 4
            $null = $r.TakeGameSounds()
            for ($i = 0; $i -lt 120; $i++) {
                $bird = @(Get-GameCourse $r 'Bird')[0]
                if ($Jump -and $bird -and $bird.X -le 13.5 -and @(Get-GameCourse $r)[0].State -eq 'stands') { Send-GameKey $r Spacebar; $Jump = $false }
                $r.AdvanceGame(0.025)
            }
            $r
        }
        $r = & $fly $false
        $r.GameResult.Hits | Should -Be 1
        $r.GameResult.Stomps | Should -Be 0
        $r.GetPlainScreen(80, 24)[22] | Should -Match '^ ✗ Hit by I\.1 A test to look at '
        $r.Close()
        $r = & $fly $true
        $r.GameResult.Hits | Should -Be 0
        $r.GameResult.Stomps | Should -Be 1
        $r.GameResult.Coins | Should -Be 6
        $sounds = $r.TakeGameSounds()
        $sounds | Should -Contain 'Stomp'
        $sounds | Should -Not -Contain 'Hit'
        $r.Close()
    }

    It 'Keeps what is in the way of each other apart: a bird turns away. And puts what the run sends on the bridge the route is on' {
        # A bird that would be over a creature when the runner has to jump on it flies up, into the sky,
        # and touches nothing there.
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'F.1' -Severity 'Low'
        Complete-GameTest $r 'I.1' -Result 'Investigate'
        $r.AdvanceGame(0.6)
        $bird = @(Get-GameCourse $r 'Bird')[0]
        $bird.State | Should -Be 'away'
        $r.AdvanceGame(1.5)
        $bird = @(Get-GameCourse $r 'Bird')[0]
        # (Seven rows over the highest of the two levels of this screen: over what stands there, and its name.)
        $bird.Y | Should -Be 15
        @(Get-GameCourse $r 'Biter')[0].Y | Should -Be 0
        Invoke-GameStomp $r
        $r.GameResult.Stomps | Should -Be 1
        $r.GameResult.Hits | Should -Be 0
        # One that comes a second and a half after the creature is in nobody's way.
        Complete-GameTest $r 'F.2' -Severity 'Low'
        $r.AdvanceGame(1.5)
        Complete-GameTest $r 'I.2' -Result 'Investigate'
        $r.AdvanceGame(0.05)
        @(Get-GameCourse $r 'Bird' | Where-Object Id -EQ 'I.2')[0].State | Should -Be 'flies'
        $r.Close()

        # A failed test or an error does not end a bridge: the creature and the plant are on it, where a
        # runner that is on the bridge meets them. The creature walks along the bridge, and no further
        # than where the bridge starts.
        foreach ($result in 'Failed', 'Error') {
            $t = New-GameDashboard -Width 165 -Height 52
            $r = $t.Renderer
            Send-GameText $r 'dead'
            1..5 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
            $r.AdvanceGame(2.5)
            $bridge = @(Get-GameCourse $r 'Platform')[0]
            $bridge.To | Should -Be ([double]::MaxValue)
            $bridge.Surface | Should -Be 4
            $bridge.Route | Should -BeTrue
            Complete-GameTest $r 'T.1' -Result $result -Severity 'Low'
            $r.AdvanceGame(0.5)
            $thing = @(Get-GameCourse $r 'Biter', 'Plant')[0]
            $thing.Id | Should -Be 'T.1'
            $thing.Y | Should -Be 4
            @(Get-GameCourse $r 'Platform')[0].To | Should -Be ([double]::MaxValue)
            # Nobody jumps onto the bridge: the runner runs under it, and under what is on it.
            $ahead = @(for ($i = 0; $i -lt 400; $i++) {
                $r.AdvanceGame(0.025)
                $platform = @(Get-GameCourse $r 'Platform')[0]
                $thing = @(Get-GameCourse $r 'Biter', 'Plant')[0]
                if ($platform -and $thing) { $thing.X - $platform.From }
            })
            ($ahead | Measure-Object -Minimum).Minimum | Should -BeGreaterOrEqual 0
            $r.GameResult.Hits | Should -Be 0
            $r.Close()
        }
        # A runner on the bridge stomps the creature there, as on the ground.
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..5 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $null = Invoke-GameBot $r -Seconds 2.5
        Complete-GameTest $r 'F.1' -Severity 'High'
        $null = Invoke-GameBot $r -Seconds 9
        $result = $r.GameResult
        $result.Coins | Should -Be 5
        $result.Stomps | Should -Be 1
        $result.Hits | Should -Be 0
        $r.Close()
    }

    It 'Adds walkers, attacks, plants and birds of its own to the course, the same ones for the same dice, and none without them' {
        # Two games with the same dice and the same run are the same game, key for key.
        $play = {
            param([int] $Seed, [bool] $Extras = $true)
            $t = New-GameDashboard -Width 124 -Height 38 -Total 60 -Seed $Seed -Extras:$Extras
            $r = $t.Renderer
            Send-GameText $r 'dead'
            $course = [System.Text.StringBuilder]::new()
            $kinds = @{}
            foreach ($second in 1..30) {
                if ($second % 2 -eq 0) { Complete-GameTest $r "P.$second" -Result 'Passed' }
                foreach ($kind in Invoke-GameBot $r -Seconds 1) { $kinds[$kind] = $true }
                $null = $course.AppendLine(($r.GetGameCourse() -join ' | '))
            }
            $screen = $r.GetPlainScreen(124, 38)[1..37] -join "`n"
            $null = Invoke-GameBot $r -Seconds 8
            $result = $r.GameResult
            $r.Close()
            [pscustomobject]@{ Course = $course.ToString(); Kinds = @($kinds.Keys | Sort-Object); Result = $result; Screen = $screen }
        }
        $one = & $play 21
        $same = & $play 21
        $other = & $play 22
        $same.Course | Should -Be $one.Course
        $same.Screen | Should -Be $one.Screen
        $other.Course | Should -Not -Be $one.Course
        # In half a minute of a run that sends no failed tests the dice put things of several kinds in the
        # way, between these two games at least three of the four, and bridges beside the route.
        $kinds = @($one.Kinds + $other.Kinds | Select-Object -Unique)
        @($kinds | Where-Object { $_ -in 'Walker', 'Attack', 'Plant', 'Bird' }).Count | Should -BeGreaterOrEqual 3
        ($one.Course + $other.Course) | Should -Match 'Platform \S+ \S+ \d+ beside'
        # They are worth nothing: the fifteen passed tests are the score, of the sixty of the run, which
        # has DC01 for its last tenth. What was stomped of them counts as stomped, and for the streak.
        $one.Result.Hits | Should -Be 0
        $one.Result.Coins | Should -Be 15
        $one.Result.Score | Should -Be 2250
        $one.Result.Stomps | Should -BeGreaterThan 2
        $one.Result.BestStreak | Should -Be (15 + $one.Result.Stomps)
        # Without the dice there is nothing on the course but the run, and the route goes up for passed tests only.
        $none = & $play 21 $false
        $none.Kinds | Should -BeNullOrEmpty
        $none.Course | Should -Not -Match 'beside'
        $none.Result.Stomps | Should -Be 0
        $none.Result.Score | Should -Be 2250
    }

    It 'Gives a <Kind> a name of its own, and no points for stomping it' -ForEach @(
        @{ Kind = 'Walker'; Seed = 21; Speed = 2; Shape = '▗█▖'; Feet = '▛ ▜', '▜ ▛'; Title = 'a habit'; Colour = '38;5;73' }
        @{ Kind = 'Attack'; Seed = 22; Speed = 3.5; Shape = '▟▀▙'; Feet = '▛▄▜', '▜▄▛'; Title = 'an attack'; Colour = '38;5;168' }
    ) {
        $t = New-GameDashboard -Total 10 -Seed $Seed -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # The first one of these dice that is well ahead: the runner follows the route until then.
        $first = { @(Get-GameCourse $r $Kind | Where-Object { $_.X -gt 30 -and $_.X -lt 55 })[0] }
        for ($i = 0; $i -lt 2400 -and -not (& $first); $i++) { $null = Invoke-GameBot $r -Seconds 0.025 }
        $thing = & $first
        $thing | Should -Not -BeNullOrEmpty
        $thing.Width | Should -Be 3
        $thing.Height | Should -Be 2
        $thing.Count | Should -Be 0
        # Small, and named for something a tenant is better off without: not for a test.
        $thing.Id | Should -Match '^[\x20-\x7E]{2,20}$'
        $thing.Id | Should -Not -Match '^(MT|CISA|EIDSCA|ORCA)\.'
        # It walks, on top of the ground that goes by: an attack a little faster than a walker.
        $world = @(Get-GameCourse $r)[0].Speed
        $null = Invoke-GameBot $r -Seconds 0.4
        $now = @(Get-GameCourse $r $Kind | Where-Object Id -EQ $thing.Id)[0]
        [math]::Round(($thing.X - $now.X) / 0.4 - $world, 1) | Should -Be $Speed
        $screen = $r.GetPlainScreen(80, 24)
        $ground = (Get-GameView $screen).Ground
        $row = $ground - [int]$now.Y - 2
        $at = $screen[$row].IndexOf($Shape, 16)
        $at | Should -BeGreaterThan 16
        $screen[$row + 1].Substring($at, 3) | Should -BeIn $Feet
        $screen[$row - 1] | Should -Match ([regex]::Escape($thing.Id))
        $r.ItemFinished('Skipped')
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;${Colour}") + '(;48;5;235)?m' + [regex]::Escape($Shape))
        # Stomped: one more in the streak, and no points. Its name rises from where it was, with a no before it.
        $before = $r.GameResult
        $said = $false
        for ($i = 0; $i -lt 400 -and @(Get-GameCourse $r $Kind | Where-Object Id -EQ $thing.Id).Count; $i++) { $null = Invoke-GameBot $r -Seconds 0.025 }
        $r.GetPlainScreen(80, 24)[22] | Should -Match ('^ ✓ Stomped ' + [regex]::Escape($thing.Id) + ' ' + $Title)
        foreach ($step in 1..12) {
            if (($r.GetPlainScreen(80, 24)[2..21] -join "`n") -match ('no ' + [regex]::Escape($thing.Id))) { $said = $true }
            $r.AdvanceGame(0.025)
        }
        $said | Should -BeTrue
        $result = $r.GameResult
        $result.Stomps | Should -BeGreaterThan $before.Stomps
        $result.Hits | Should -Be 0
        $result.Score | Should -Be 0
        $result.BestStreak | Should -Be $result.Stomps
        $r.Close()
    }

    It 'Gives the birds of the dice the names of threat actors, and has the three lists of names in one place' {
        $t = New-GameDashboard -Width 124 -Height 38 -Total 10 -Seed 21 -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $names = @{}
        $drawn = $false
        for ($i = 0; $i -lt 1600; $i++) {
            $null = Invoke-GameBot $r -Seconds 0.05
            foreach ($bird in Get-GameCourse $r 'Bird') {
                $names[$bird.Id] = $true
                if (($r.GetPlainScreen(124, 38) -join "`n").Contains($bird.Id)) { $drawn = $true }
            }
            if ($names.Count -ge 4) { break }
        }
        $names.Count | Should -BeGreaterOrEqual 4
        $drawn | Should -BeTrue
        # Names of the weather, as Microsoft gives them: two words, or a storm with a number.
        foreach ($name in $names.Keys) { $name | Should -Match '^([A-Z][a-z]+ (Blizzard|Typhoon|Tempest|Sandstorm|Sleet)|Storm-\d{4})$' }
        $r.Close()
        # The names are in the renderer, one list after the other.
        $flags = [System.Reflection.BindingFlags]'NonPublic, Static'
        $lists = foreach ($field in 'GameHabits', 'GameAttacks', 'GameActors', 'GameDirectory') { , [string[]][Maester.Engine.MtConsoleRenderer].GetField($field, $flags).GetValue($null) }
        $lists[0] | Should -Contain 'NTLM'
        $lists[1] | Should -Contain 'ransomware'
        $lists[1] | Should -Contain 'kerberoasting'
        $lists[2] | Should -Contain 'Midnight Blizzard'
        $lists[2] | Should -Contain 'Storm-0558'
        $lists[3] | Should -Contain 'krbtgt'
        foreach ($list in $lists) {
            $list.Count | Should -BeGreaterThan 15
            @($list | Select-Object -Unique).Count | Should -Be $list.Count
            foreach ($name in $list) { $name | Should -Match '^[\x20-\x7E]{2,20}$' }
        }
    }

    It 'Is played without a hit, and for all of 10,000, by a player that misses nothing in a run in which every test passes (<Width>x<Height>)' -ForEach @(
        @{ Width = 80; Height = 24; Seed = 31 }, @{ Width = 124; Height = 38; Seed = 32 }, @{ Width = 165; Height = 52; Seed = 33 }
    ) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 40 -Seed $Seed -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $kinds = @{}
        $levels = @{}
        foreach ($n in 1..40) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            foreach ($kind in Invoke-GameBot $r -Seconds 1) { $kinds[$kind] = $true }
            $levels[[int]@(Get-GameCourse $r)[0].Y] = $true
        }
        foreach ($kind in Invoke-GameBot $r -Seconds 8) { $kinds[$kind] = $true }
        # What the dice put in the way was there, the route was on more floors than one, and nothing
        # hit the runner or took a coin from it: every coin of the run is on a route that can be followed.
        @($kinds.Keys | Where-Object { $_ -in 'Walker', 'Attack', 'Plant', 'Bird' }).Count | Should -BeGreaterOrEqual 3
        $levels.Count | Should -BeGreaterThan 1
        $result = $r.GameResult
        $result.Hits | Should -Be 0
        $result.Coins | Should -Be 40
        $result.Stomps | Should -BeGreaterThan 3
        $result.Boss | Should -BeFalse
        $result.Score | Should -Be 10000
        (Get-GameTopLine $r.GetPlainScreen($Width, $Height)) | Should -Match '♥ ♥ ♥  SCORE 10,000  STREAK \d+ '
        $r.Close()
    }

    It 'Is played for all there is to earn by a player that misses nothing in a run in which tests fail as well (<Width>x<Height>)' -ForEach @(
        @{ Width = 80; Height = 24; Seed = 57 }, @{ Width = 124; Height = 38; Seed = 57 }, @{ Width = 165; Height = 52; Seed = 57 }
    ) {
        # A run of forty tests in which two of five fail, of every severity: a failed test that is stomped is half a test.
        $t = New-GameDashboard -Width $Width -Height $Height -Total 40 -Seed $Seed -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $results = 'Passed', 'Failed', 'Passed', 'Passed', 'Failed'
        $severities = 'High', 'Critical', 'Low', 'Medium', 'High', 'Critical', 'Low'
        $passed = 0
        foreach ($n in 1..40) {
            $result = $results[$n % 5]
            if ($result -eq 'Passed') { $passed++ }
            Complete-GameTest $r "T.$n" -Result $result -Severity $severities[$n % 7]
            $null = Invoke-GameBot $r -Seconds 1
        }
        $null = Invoke-GameBot $r -Seconds 9
        # Nothing hit the runner, no coin went by and no failed test walked past: each of them is on
        # a route that can be followed. Nothing is met under a bridge beside the route, where the jump
        # for it would come down on the bridge: with these dice a failed test would be, at 124 columns.
        $result = $r.GameResult
        $result.Hits | Should -Be 0
        $result.Coins | Should -Be $passed
        $result.Score | Should -Be ([math]::Floor(10000 * (1000 * $passed + 500 * (40 - $passed)) / 40000))
        $r.Close()
    }

    It 'Collects a coin from as high as the second jump goes: no coin is missed for being jumped over' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'P.1' -Result 'Passed'
        do { $r.AdvanceGame(0.025) } while (@(Get-GameCourse $r 'Coin')[0].X -gt 10.5)
        # Two jumps, the second at the top of the first: the runner is over the coin when it is as
        # high as it gets, more than eight rows up, as it is over a coin right before a giant.
        Send-GameKey $r Spacebar
        $r.AdvanceGame(0.3)
        Send-GameKey $r Spacebar
        $high = 0
        foreach ($i in 1..40) {
            $r.AdvanceGame(0.025)
            if (-not $high -and @(Get-GameCourse $r 'Coin').Count -eq 0) { $high = (Get-GameCourse $r 'Runner').Y }
        }
        $high | Should -BeGreaterThan 8
        $r.GameResult.Coins | Should -Be 1
        $r.GameResult.Score | Should -Be 1000
        $r.Close()
    }

    It 'Adds less to the course the more failed tests the run sends' {
        # What the dice added in forty seconds, to a run of passed tests and to one in which every other test fails.
        $count = {
            param([string[]] $Results)
            $t = New-GameDashboard -Width 124 -Height 38 -Total 400 -Seed 41 -Extras
            $r = $t.Renderer
            Send-GameText $r 'dead'
            $added = 0
            $was = @()
            foreach ($n in 1..40) {
                Complete-GameTest $r "T.$n" -Result $Results[$n % $Results.Count] -Severity 'Low'
                $null = Invoke-GameBot $r -Seconds 1
                # Each is counted when it is first seen far ahead.
                $far = @(Get-GameCourse $r 'Walker', 'Attack', 'Plant', 'Bird' | Where-Object { $_.Count -eq 0 -and $_.Id -notmatch '^T\.' -and $_.X -gt 60 })
                $added += @($far | Where-Object { $thing = $_; -not ($was | Where-Object { $_.Kind -eq $thing.Kind -and $_.Id -eq $thing.Id -and [math]::Abs($_.X - $thing.X) -lt 45 }) }).Count
                $was = $far
            }
            $hits = $r.GameResult.Hits
            $r.Close()
            [pscustomobject]@{ Added = $added; Hits = $hits }
        }
        $quiet = & $count 'Passed'
        $busy = & $count 'Passed', 'Failed'
        $quiet.Hits | Should -Be 0
        $busy.Hits | Should -Be 0
        $quiet.Added | Should -BeGreaterThan 5
        $busy.Added | Should -BeGreaterThan 0
        $busy.Added | Should -BeLessThan ($quiet.Added / 2)
    }

    It 'Takes the route up a level at a time while passed tests go on, with the coin of each step in the air, and then to the ground for three (<Width>x<Height>)' -ForEach @(
        # Three on the ground; the coin of the step; five on the first bridge; and so on, for as many levels
        # as the screen has room for under the sky that is kept for the counter of the run: two on a low
        # screen, three from 36 rows, and four on a tall one.
        @{ Width = 80; Height = 24; Expected = '1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 1 1 1 3 5 5' }
        @{ Width = 90; Height = 27; Expected = '1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 1 1 1 3 5 5' }
        @{ Width = 124; Height = 38; Expected = '1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 11 13 13 13 13 13 1 1 1 3 5 5 5 5 5 7 9 9 9 9 9' }
        @{ Width = 165; Height = 52; Expected = '1 1 1 3 5 5 5 5 5 7 9 9 9 9 9 11 13 13 13 13 13 15 17 17 17 17 17 1 1 1 3 5 5 5 5 5' }
    ) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $rows = @{}
        $floors = @{}
        foreach ($n in 1..36) {
            Complete-GameTest $r ('P.{0:00}' -f $n) -Result 'Passed'
            Invoke-GameCourse $r -Seconds 1
            foreach ($coin in Get-GameCourse $r 'Coin') { $rows[$coin.Id] = $coin.Y }
            foreach ($bridge in Get-GameCourse $r 'Platform') { $floors[$bridge.Surface] = $bridge.Route }
        }
        Invoke-GameCourse $r -Seconds 8
        (@($rows.Keys | Sort-Object | ForEach-Object { $rows[$_] }) -join ' ') | Should -Be $Expected
        # Without the dice every bridge is of the route, and the levels are four rows apart.
        $floors.Values | Should -Not -Contain $false
        ($floors.Keys | Sort-Object) | Should -Be @(4, 8, 12, 16 | Where-Object { $_ -lt [int]($Expected -split ' ' | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum })
        # A runner that follows the route has every coin of it, the ones in the air among them.
        $r.GameResult.Coins | Should -Be 36
        $r.GameResult.Hits | Should -Be 0
        $r.GameScore | Should -Be 9000
        $r.Close()
    }

    It 'Brings DC01 on when the run is near its end, and not at all in a run of fewer than fifty tests or of less than two minutes' {
        # A run of passed tests, one every so many seconds: the number of the test at which DC01 is on the course.
        $run = {
            param([int] $Total, [double] $SecondsEach, [int] $Until, [int] $Before = 0)
            $t = New-GameDashboard -Total $Total
            $r = $t.Renderer
            $at = 0
            foreach ($n in 1..$Until) {
                if ($n -eq $Before + 1) { Send-GameText $r 'dead' }
                Complete-GameTest $r "P.$n" -Result 'Passed'
                $r.AdvanceGame($SecondsEach)
                if (-not $at -and $n -gt $Before -and @(Get-GameCourse $r 'Boss').Count) { $at = $n }
            }
            $result = $r.GameResult
            $r.Close()
            [pscustomobject]@{ At = $at; Boss = $result.Boss; Down = $result.BossDown }
        }
        # One every second and a half, a hundred of them: it comes when the rest takes a minute or
        # less, and at the sixtieth test the forty that are left take fifty-nine seconds.
        $fast = & $run 100 1.5 70
        $fast.At | Should -Be 60
        $fast.Boss | Should -BeTrue
        $fast.Down | Should -BeFalse
        # One every 2.9 seconds: a minute or less is left at the eightieth.
        (& $run 100 2.9 90).At | Should -Be 80
        # One every ten seconds: at nine tenths of the run, whatever the time that is left.
        (& $run 100 10 95).At | Should -Be 90
        # A game that is put on screen later than that has it at once.
        (& $run 100 10 96 -Before 95).At | Should -Be 96
        # Fifty tests are enough for it, one every three seconds. Forty-nine are not: such a run has none.
        (& $run 50 3 40).At | Should -Be 30
        $short = & $run 49 3 49
        $short.At | Should -Be 0
        $short.Boss | Should -BeFalse
        # Nor has a run whose tests take less than two minutes, however many they are: it has no room
        # for the fight. A hundred tests in a hundred seconds, and the same run opened late.
        $brief = & $run 100 1 100
        $brief.At | Should -Be 0
        $brief.Boss | Should -BeFalse
        $late = & $run 100 1 100 -Before 95
        $late.At | Should -Be 0
        $late.Boss | Should -BeFalse
    }

    It 'Counts the tests as all of the score in a run that is too short for DC01' {
        # Sixty tests in a minute: no DC01, and a player that misses nothing has all of 10,000. That
        # the run is too short is said when DC01 would be due, at half of it: until then the tests
        # count as nine tenths of the score, and from then on as all of it.
        $t = New-GameDashboard -Total 60
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..60) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            $null = Invoke-GameBot $r -Seconds 1
            @(Get-GameCourse $r 'Boss').Count | Should -Be 0
            $now = $r.GameResult
            if ($n -lt 30) { $now.Score | Should -Be ([math]::Floor(9000 * $now.Coins / 60)) }
            if ($n -gt 30) { $now.Score | Should -Be ([math]::Floor(10000 * $now.Coins / 60)) }
            $now.Boss | Should -BeFalse
        }
        $null = Invoke-GameBot $r -Seconds 8
        $result = $r.GameResult
        $result.Boss | Should -BeFalse
        $result.Coins | Should -Be 60
        $result.Score | Should -Be 10000
        $r.Stop()
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Not -Match 'DC01'
        $r.Close()

        # A game that was put away before the middle of such a run is told when the tests stop.
        $t = New-GameDashboard -Total 60
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..10) { Complete-GameTest $r "P.$n" -Result 'Passed'; $null = Invoke-GameBot $r -Seconds 1 }
        Send-GameKey $r Escape
        $r.IsGameShown | Should -BeFalse
        foreach ($n in 11..60) { Complete-GameTest $r "P.$n" -Result 'Passed'; $r.AdvanceGame(1) }
        $r.GameResult.Score | Should -Be ([math]::Floor(9000 * $r.GameResult.Coins / 60))
        $r.Stop()
        $result = $r.GameResult
        $result.Boss | Should -BeFalse
        $result.Coins | Should -BeGreaterThan 5
        $result.Score | Should -Be ([math]::Floor(10000 * $result.Coins / 60))
        $r.Close()
    }

    It 'Has DC01 stand ahead of the runner, throw things and charge: four stomps decommission it, for a tenth of the score' {
        $t = New-GameDashboard -Total 60
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $announced = $false
        # A test every two and a half seconds: a run of two minutes and a half, which has room for the
        # fight. DC01 comes with a minute to go, at the thirty-sixth test.
        foreach ($n in 1..36) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            foreach ($step in 1..25) {
                $null = Invoke-GameBot $r -Seconds 0.1
                if ($r.GetPlainScreen(80, 24)[22] -match '^ ! Ahead, and it takes two jumps: DC01 the last') { $announced = $true }
            }
        }
        # It is announced, and comes on screen: a rack nine cells wide and six rows high, which takes four stomps.
        $announced | Should -BeTrue
        $boss = @(Get-GameCourse $r 'Boss')[0]
        $boss.Id | Should -Be 'DC01'
        $boss.Width | Should -Be 9
        $boss.Height | Should -Be 6
        $boss.Count | Should -Be 4
        $boss.State | Should -BeIn 'arrives', 'throws'
        $null = $r.TakeGameSounds()
        # The fight, while the run goes on at a test a second: what DC01 does, what it throws, and the score at each stomp.
        $states = [System.Collections.Generic.List[string]]::new()
        $thrown = @{}
        $scores = @{}
        $names = [string[]][Maester.Engine.MtConsoleRenderer].GetField('GameDirectory', [System.Reflection.BindingFlags]'NonPublic, Static').GetValue($null)
        $n = 36
        $drawn = $null
        $sinking = [System.Collections.Generic.List[int]]::new()
        # And how it goes from round to round, by the stomps it still takes: how far it charges in a
        # tenth of a second, how many things it throws, and how many of them through the air.
        $charge = @{ 4 = 0.0; 3 = 0.0; 2 = 0.0; 1 = 0.0 }
        $throws = @{ 4 = 0; 3 = 0; 2 = 0; 1 = 0 }
        $air = @{ 4 = 0; 3 = 0; 2 = 0; 1 = 0 }
        $before = $null
        $newest = [double]::NegativeInfinity
        for ($i = 0; $i -lt 900 -and $boss; $i++) {
            if ($i % 10 -eq 9 -and $n -lt 60) { $n++; Complete-GameTest $r "P.$n" -Result 'Passed' }
            $null = Invoke-GameBot $r -Seconds 0.1
            $boss = @(Get-GameCourse $r 'Boss')[0]
            if (-not $boss) { break }
            if ($before -and $before.State -eq 'charges' -and $boss.State -eq 'charges') { $charge[$boss.Count] = [math]::Max($charge[$boss.Count], $before.X - $boss.X) }
            $before = $boss
            # What it throws starts at it and goes to the left: a new one is further right than all there was.
            $shots = @(Get-GameCourse $r 'Packet', 'Bird')
            foreach ($shot in $shots) {
                if ($shot.X -gt $newest -and $boss.State -eq 'throws') {
                    $throws[$boss.Count]++
                    if ($shot.Kind -eq 'Bird') { $air[$boss.Count]++ }
                }
            }
            $newest = $(if ($shots.Count) { ($shots.X | Measure-Object -Maximum).Maximum } else { [double]::NegativeInfinity })
            if ($states.Count -eq 0 -or $states[-1] -ne $boss.State) { $states.Add($boss.State) }
            if (-not $scores.ContainsKey($boss.Count)) { $scores[$boss.Count] = $r.GameScore }
            if ($boss.State -eq 'throws') {
                # It stands near the right edge, and nothing of the run is put on the course.
                $boss.X | Should -Be 51
                @(Get-GameCourse $r 'Coin' | Where-Object X -GT 20).Count | Should -Be 0
                if (-not $drawn) { $drawn = $r.GetPlainScreen(80, 24) }
                # It is whole on every screen: the name of what it just threw is beside it, not on it.
                $screen = $r.GetPlainScreen(80, 24)
                $row = @(0..23 | Where-Object { $screen[$_].Contains('DC01 ■') })[0]
                @($screen[$row..($row + 6)] | ForEach-Object { $_.Substring(67, 9) -replace '□', '■' }) | Should -Be @('DC01 ■■■■', '▛▀▀▀▀▀▀▀▜', '▌● ━━━━ ▐', '▌━━━━━━━▐', '▌● ━━━━ ▐', '▌▚▚▚▚▚▚▚▐', '▙▄▄▄▄▄▄▄▟')
            }
            if ($boss.State -eq 'falls') {
                # Its collapse: the rows of it that are left over the ground, and its name is gone.
                $screen = $r.GetPlainScreen(80, 24)
                ($screen -join "`n") | Should -Not -Match 'DC01 [■□]'
                $sinking.Add(@($screen | Where-Object { $_ -match '▛▀{7}▜|▌.{7}▐|▙▄{7}▟' }).Count)
            }
            foreach ($shot in Get-GameCourse $r 'Packet', 'Bird') {
                $names | Should -Contain $shot.Id
                $thrown[$shot.Kind] = $shot.Y
            }
        }
        # It took a second and more to sink into the ground, row after row, down to nothing.
        $sinking.Count | Should -BeGreaterThan 8
        $sinking[0] | Should -BeGreaterThan 3
        $sinking[-1] | Should -BeLessThan 2
        foreach ($k in 1..($sinking.Count - 1)) { $sinking[$k] | Should -BeLessOrEqual $sinking[$k - 1] }
        # It threw along the ground and through the air, over the head of a runner on the ground.
        $thrown['Packet'] | Should -Be 0
        $thrown['Bird'] | Should -BeGreaterThan 4
        # Round after round: it throws, warns and charges, takes its stomp and goes back, and after the fourth it falls.
        ($states -join ' ') | Should -Match '^(arrives )?(throws warns charges back ){3}throws warns charges falls$'
        # Every stomp makes it a little quicker: it charges at 42, 44, 46 and 48 cells a second.
        foreach ($left in 4, 3, 2, 1) { $charge[$left] | Should -BeGreaterThan (4.19 + 0.2 * (4 - $left)) -Because "of its charge with $left to go" }
        foreach ($left in 4, 3, 2, 1) { $charge[$left] | Should -BeLessThan (4.21 + 0.2 * (4 - $left)) -Because "of its charge with $left to go" }
        # And from the second stomp it throws one thing more in a round, three or four of them, and at
        # least one of them through the air. (Its first round had begun before this looked.)
        $throws[4] | Should -BeLessOrEqual 3
        $throws[3] | Should -BeIn 2, 3
        $throws[2] | Should -BeIn 3, 4
        $throws[1] | Should -BeIn 3, 4
        $air[2] | Should -BeGreaterThan 0
        $air[1] | Should -BeGreaterThan 0
        # Every stomp is a quarter of its tenth of the score.
        ($scores[3] - $scores[4]) | Should -Be 250
        ($scores[2] - $scores[3]) | Should -Be 250
        ($scores[1] - $scores[2]) | Should -Be 250
        # As it is drawn: its name and what it still takes over it, and its two lights.
        $top = @(0..23 | Where-Object { $drawn[$_] -match 'DC01 ■■■■' })[0]
        $at = $drawn[$top].IndexOf('DC01 ■■■■')
        $at | Should -Be (11 + 5 + 51)
        @($drawn[($top + 1)..($top + 6)] | ForEach-Object { $_.Substring($at, 9) }) | Should -Be @('▛▀▀▀▀▀▀▀▜', '▌● ━━━━ ▐', '▌━━━━━━━▐', '▌● ━━━━ ▐', '▌▚▚▚▚▚▚▚▐', '▙▄▄▄▄▄▄▄▟')
        $drawn[$top + 7] | Should -Match '^▔+$'
        # The sound of its going down is its own, and the warning before each charge is heard.
        $sounds = $r.TakeGameSounds()
        @($sounds | Where-Object { $_ -eq 'Down' }).Count | Should -Be 1
        @($sounds | Where-Object { $_ -eq 'Snap' }).Count | Should -Be 4
        $sounds | Should -Not -Contain 'Hit'
        # Decommissioned: the ticker says so, and for four seconds a line is on the wall of the game, with
        # DE and AD in the colour that stands out.
        $result = $r.GameResult
        $result.Boss | Should -BeTrue
        $result.BossDown | Should -BeTrue
        $screen = $r.GetPlainScreen(80, 24)
        $screen[22] | Should -Match '^ ✓ Stomped DC01 decommissio\S* \+250 '
        ($screen -join "`n") | Should -Match '\n {22}DC01 DEcommissioned\. AD is no more\.\n'
        $r.ItemFinished('Skipped')
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;3;38;5;252mDC01 $esc[0;1;3;38;5;196mDE$esc[0;3;38;5;252mcommissioned. $esc[0;1;3;38;5;196mAD $esc[0;3;38;5;252mis no more."))
        $null = Invoke-GameBot $r -Seconds 4.2
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Not -Match 'DEcommissioned'
        # The course goes on with what is left of the run, and a player that missed nothing has all of 10,000.
        while ($n -lt 60) { $n++; Complete-GameTest $r "P.$n" -Result 'Passed'; $null = Invoke-GameBot $r -Seconds 1 }
        $null = Invoke-GameBot $r -Seconds 10
        $result = $r.GameResult
        $result.Coins | Should -Be 60
        $result.Hits | Should -Be 0
        $result.Score | Should -Be 10000
        $r.Stop()
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Match '│ +DC01 decommissioned +│'
        $r.Close()
    }

    It 'Has DC01 hit a runner that is in its way, and says that it still stands when the tests stop before it is down' {
        foreach ($asciiOnly in $false, $true) {
            $t = New-GameDashboard -Total 60 -Ascii:$asciiOnly
            $r = $t.Renderer
            Send-GameText $r 'dead'
            foreach ($n in 1..36) { Complete-GameTest $r "P.$n" -Result 'Passed'; $null = Invoke-GameBot $r -Seconds 2.5 }
            # A runner that deals with what it throws and stands in the way of its charge is hit by it,
            # and it goes back to where it stood. After that nobody is at the key: what it throws along
            # the ground hits as well.
            $by = @{}
            $seen = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt 600 -and @(Get-GameCourse $r)[0].State -ne 'over'; $i++) {
                if ($by.Count) { $r.AdvanceGame(0.1) } else { $null = Invoke-GameBot $r -Seconds 0.1 -NotBoss }
                $screen = $r.GetPlainScreen(80, 24)
                $null = $seen.Append(($screen -join "`n"))
                if ($asciiOnly) { foreach ($line in $screen) { $line | Should -Match '^[\x20-\x7E]*$' } }
                if ($screen[22] -match '^ . Hit by DC01 the last') { $by['DC01'] = $true }
                if ($screen[22] -match '^ . Hit by .+ thrown by') { $by['thrown'] = $true }
            }
            @(Get-GameCourse $r)[0].State | Should -Be 'over'
            $by['DC01'] | Should -BeTrue
            $by['thrown'] | Should -BeTrue
            if ($asciiOnly) {
                # Without Unicode it is drawn with these.
                $all = $seen.ToString()
                $all | Should -Match 'DC01 ####'
                $all | Should -Match ([regex]::Escape('+-------+') + '\n.*' + [regex]::Escape('|o ==== |'))
                $all | Should -Match ([regex]::Escape('+-+') + '.*\n.*' + [regex]::Escape('+-+'))
            }
            # The tests stop: the card of the run says how it is with DC01.
            $r.Stop()
            $card = $r.GetPlainScreen(80, 24) -join "`n"
            $card | Should -Match 'RUN COMPLETE'
            $card | Should -Match 'DC01 still standing'
            $r.GameResult.Boss | Should -BeTrue
            $r.GameResult.BossDown | Should -BeFalse
            # The tests are nine tenths of the score in such a run: thirty-six of sixty collected is 5,400 at the most.
            $r.GameResult.Score | Should -BeLessOrEqual 5400
            $r.Close()
        }
    }

    It 'Writes the ID of its test over a coin, small and dim, where it is in the way of no other name' {
        # Coins that are far apart have their names, each in the middle over its coin.
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..3) { Complete-GameTest $r "MT.100$n" -Result 'Passed'; $r.AdvanceGame(1) }
        $screen = $r.GetPlainScreen(165, 52)
        $ground = (Get-GameView $screen).Ground
        $coins = @(Get-GameCourse $r 'Coin')
        $coins.Count | Should -Be 3
        foreach ($coin in $coins) {
            $at = 22 + 5 + [math]::Floor($coin.X + 0.001) - 2
            $screen[$ground - 4].Substring($at - 1, 9).Trim() | Should -Be $coin.Id
        }
        $r.ItemFinished('Skipped')
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;2;32m") + 'MT\.100\d')
        $r.Close()

        # Coins that are close to one another: as many have their name as there is room for, and no name
        # is cut or runs into the next. Three coins six cells apart have room for the first and the third.
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..3) { Complete-GameTest $r "MT.100$n" -Result 'Passed' }
        $r.AdvanceGame(1.5)
        $screen = $r.GetPlainScreen(165, 52)
        # (The flame over the head of the runner is in that row too, at the left.)
        $names = $screen[(Get-GameView $screen).Ground - 4].Substring(40)
        $names.Trim() | Should -Match '^MT\.1001 {5}MT\.1003$'
        $r.Close()

        # A coin of several tests has the ID of the first of them and how many more; and where there is
        # no room for that, how many tests it is.
        $t = New-GameDashboard -Width 165 -Height 52 -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..20) { Complete-GameTest $r ('CISA.MS.AAD.{0:00}' -f $n) -Result 'Passed' }
        $r.AdvanceGame(2)
        $screen = $r.GetPlainScreen(165, 52) -join "`n"
        $screen | Should -Match 'CISA\.MS\.AAD\.01 \+2'
        $screen | Should -Match ' ×\d '
        ([regex]::Matches($screen, 'CISA\.MS\.AAD\.\d\d \+\d')).Count | Should -BeLessThan @(Get-GameCourse $r 'Coin').Count
        $r.Close()

        # A coin that a creature walks over has no name while the creature is over it: the name of a coin
        # is never in the way of what is in the way. The tall creature is as high as that name and higher.
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'MT.1001' -Result 'Passed'
        $r.AdvanceGame(0.6)
        Complete-GameTest $r 'MT.1002' -Severity 'Critical'
        $seen = foreach ($i in 1..45) {
            $r.AdvanceGame(0.1)
            $screen = $r.GetPlainScreen(165, 52)
            $named = $screen[(Get-GameView $screen).Ground - 4].Contains('MT.1001')
            $apart = @(Get-GameCourse $r 'Giant')[0].X - @(Get-GameCourse $r 'Coin')[0].X
            if ($apart -gt 8) { 'ahead'; $named | Should -BeTrue }
            elseif ($apart -lt 5) { 'over'; $named | Should -BeFalse }
        }
        @($seen | Where-Object { $_ -eq 'ahead' }).Count | Should -BeGreaterThan 10
        @($seen | Where-Object { $_ -eq 'over' }).Count | Should -BeGreaterThan 2
        $r.Close()

        # No name is ever over the counter of the run or its caption: they are in rows of the sky that
        # nothing of the course is in. On 30 rows that is the counter in small, over two levels.
        $t = New-GameDashboard -Width 100 -Height 30 -Total 400
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..12) { Complete-GameTest $r "P.$n" -Result 'Passed'; $r.AdvanceGame(0.4) }
        $screen = $r.GetPlainScreen(100, 30)
        $row = @(0..29 | Where-Object { $screen[$_].Contains('tests completed') })[0]
        $row | Should -BeGreaterThan 1
        foreach ($n in 13..30) { Complete-GameTest $r "P.$n" -Result 'Passed' }
        foreach ($i in 1..50) {
            $null = Invoke-GameBot $r -Seconds 0.1
            $screen = $r.GetPlainScreen(100, 30)
            # The caption, and around it nothing but a cloud that goes by behind it.
            $screen[$row] | Should -Match '^[ ▁▃▅█]*tests completed[ ▁▃▅█]*$'
            # The digits are dots, in the five rows over it: nothing else is in them, but clouds.
            foreach ($y in ($row - 5)..($row - 1)) { $screen[$y] | Should -Match '^[ ·▁▃▅█]*$' }
        }
        $r.GameResult.Coins | Should -BeGreaterThan 20
        $r.Close()
    }

    It 'Has no name of a coin in a bridge' {
        # A coin under a bridge has the row of its name in that bridge. There is no name there: a name
        # in a bridge would look like a gap in it. A name is two cells from the end of a bridge or more.
        $t = New-GameDashboard -Width 124 -Height 38 -Total 400 -Seed 21 -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $n = 0
        $under = 0
        for ($i = 0; $i -lt 1600; $i++) {
            if ($i % 20 -eq 0) { $n++; Complete-GameTest $r "P.$n" -Result 'Passed' }
            $null = Invoke-GameBot $r -Seconds 0.025
            if ($i % 4) { continue }
            $bridges = @(Get-GameCourse $r 'Platform')
            foreach ($coin in @(Get-GameCourse $r 'Coin')) {
                if ($coin.X -lt 0 -or $coin.X -gt 80) { continue }
                if ($bridges | Where-Object { $_.Surface -eq $coin.Y + 3 -and $_.From -lt $coin.X - 6 -and $_.To -gt $coin.X + 8 }) { $under++ }
            }
            ($r.GetPlainScreen(124, 38) -join "`n") | Should -Not -Match '▀ ?(P\.\d|×\d)|(P\.\d+( \+\d+)?|×\d) ?▀'
        }
        $under | Should -BeGreaterThan 20
        $r.Close()
    }

    It 'Has a spring on the route now and then, which throws the runner up two levels with one tap' {
        $find = {
            # The game of these dice until its first spring is a few cells ahead of the runner.
            $t = New-GameDashboard -Width 124 -Height 38 -Total 400 -Seed 21 -Extras
            $n = 0
            Send-GameText $t.Renderer 'dead'
            for ($i = 0; $i -lt 4000; $i++) {
                if ($i % 40 -eq 0) { $n++; Complete-GameTest $t.Renderer "P.$n" -Result 'Passed' }
                $null = Invoke-GameBot $t.Renderer -Seconds 0.025
                $spring = @(Get-GameCourse $t.Renderer 'Spring')[0]
                if ($spring -and $spring.X -lt 6) { break }
            }
            $t
        }
        $t = & $find
        $r = $t.Renderer
        $spring = @(Get-GameCourse $r 'Spring')[0]
        $spring | Should -Not -BeNullOrEmpty
        $spring.Width | Should -Be 8
        $spring.Height | Should -Be 1
        $me = @(Get-GameCourse $r)[0]
        $me.State | Should -Be 'stands'
        $me.Y | Should -Be $spring.Y
        # A bridge of the route starts over it, two levels up.
        $bridge = @(Get-GameCourse $r 'Platform' | Where-Object { $_.Route -and $_.Surface -eq $spring.Y + 8 })[0]
        $bridge.From | Should -BeLessThan $spring.X
        $bridge.From | Should -BeGreaterThan ($spring.X - 6)
        ($r.GetPlainScreen(124, 38) -join "`n") | Should -Match '▟▚▞▚▞▚▞▙'
        # One tap on it: up at 41 rows a second, which is 9.5 rows, and down on the bridge.
        $null = $r.TakeGameSounds()
        $up = 0.0
        for ($i = 0; $i -lt 80; $i++) {
            $null = Invoke-GameBot $r -Seconds 0.025
            $me = @(Get-GameCourse $r)[0]
            $up = [math]::Max($up, $me.Up)
            if ($up -gt 0 -and $me.State -eq 'stands') { break }
        }
        $up | Should -BeGreaterThan 38
        $up | Should -BeLessThan 41
        $me.Y | Should -Be ($spring.Y + 8)
        $r.TakeGameSounds() | Should -Contain 'DoubleJump'
        $r.Close()
        # A runner that runs over it without the key is not thrown.
        $t = & $find
        $r = $t.Renderer
        $floor = @(Get-GameCourse $r)[0].Y
        foreach ($step in 1..12) {
            $r.AdvanceGame(0.025)
            @(Get-GameCourse $r)[0].Up | Should -BeLessOrEqual 0
        }
        @(Get-GameCourse $r)[0].Y | Should -BeLessOrEqual $floor
        $r.Close()
    }

    It 'Has a skyline far behind the course: a colour behind the cells, which what is in front of it cuts no hole in' {
        $draw = {
            param([switch] $Extras, [switch] $NoColor)
            $t = New-GameDashboard -Width 124 -Height 38 -Extras:$Extras -NoColor:$NoColor
            Complete-GameTest $t.Renderer 'F.1' -Severity 'Low'
            Complete-GameTest $t.Renderer 'P.1' -Result 'Passed'
            Send-GameText $t.Renderer 'dead'
            $t.Renderer.AdvanceGame(1.5)
            $t.Renderer.ItemFinished('Skipped')
            $written = $t.Writer.ToString()
            $plain = $t.Renderer.GetPlainScreen(124, 38)
            $t.Renderer.Close()
            [pscustomobject]@{ Rows = @($written.Substring($written.LastIndexOf("$esc[H")) -split "`r`n"); Plain = $plain }
        }
        $with = & $draw -Extras
        $skyline = @(0..37 | Where-Object { $with.Rows[$_] -match '48;5;235' })
        # It is in the rows over the ground, no higher than eight of them, and under the counter of the run.
        $ground = (Get-GameView $with.Plain).Ground
        $skyline.Count | Should -BeGreaterThan 2
        ($skyline | Measure-Object -Maximum).Maximum | Should -Be ($ground - 1)
        ($skyline | Measure-Object -Minimum).Minimum | Should -BeGreaterOrEqual ($ground - 8)
        $caption = @(0..37 | Where-Object { $with.Plain[$_] -match 'tests completed' })[0]
        ($skyline | Measure-Object -Minimum).Minimum | Should -BeGreaterThan $caption
        # It is no character of the screen: the same screen is there without colour, which has none.
        $plain = & $draw -Extras -NoColor
        ($plain.Rows -join '') | Should -Not -Match "$esc\[[\d;]*m"
        $with.Plain[1..37] | Should -Be $plain.Plain[1..37]
        # It is of the dice: a course of the run alone has none either.
        ((& $draw).Rows -join '') | Should -Not -Match '48;5;235'
        # What stands in front of it has its own colour and the skyline behind it, in one cell: no hole.
        $both = [regex]::Matches(($with.Rows -join "`n"), [regex]::Escape("$esc[0;") + '(1;)?(38;5;\d+|\d\d);48;5;235m[^ \x1b]')
        $both.Count | Should -BeGreaterThan 0
        # It is a stretch of empty cells with that colour, and stretches without: racks, with gaps between them.
        ($with.Rows[$ground - 1]) | Should -Match ([regex]::Escape("$esc[0;48;5;235m") + ' {3,}' + [regex]::Escape("$esc[0m"))
    }

    It 'Takes a heart for a hit, of three, and gives one back for a streak of twenty-five' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 200
        $r = $t.Renderer
        Send-GameText $r 'dead'
        (Get-GameTopLine $r.GetPlainScreen(165, 52)) | Should -Match (Get-GameHud)
        @(Get-GameCourse $r)[0].Hearts | Should -Be 3
        # A streak with three hearts gives none: there are never more than three.
        1..30 | ForEach-Object { $r.ItemFinished('Passed') }
        Invoke-GameCourse $r -Seconds 12 -Width 165 -Height 52
        $r.GameResult.BestStreak | Should -Be 30
        $r.TakeGameSounds() | Should -Not -Contain 'Heart'
        @(Get-GameCourse $r)[0].Hearts | Should -Be 3
        # Two hits: one heart is left.
        foreach ($hit in 1, 2) {
            Complete-GameTest $r "F.$hit" -Severity 'Critical'
            Wait-GameHit $r $hit | Should -BeTrue
            $r.AdvanceGame(2)
        }
        @(Get-GameCourse $r)[0].Hearts | Should -Be 1
        (Get-GameTopLine $r.GetPlainScreen(165, 52)) | Should -Match '^ MAESTER RUN  ♥ ♡ ♡  SCORE [\d,]+  STREAK 0 '
        $r.TakeGameSounds() | Should -Be @('Hit', 'Hit')
        # Twenty-four in a row are not enough, and the twenty-fifth is: a heart is back, and it is heard.
        1..24 | ForEach-Object { Complete-GameTest $r "A.$_" -Result 'Passed'; Invoke-GameCourse $r -Seconds 0.5 -Width 165 -Height 52 }
        Invoke-GameCourse $r -Seconds 6 -Width 165 -Height 52
        (Get-GameTopLine $r.GetPlainScreen(165, 52)) | Should -Match '^ MAESTER RUN  ♥ ♡ ♡  SCORE [\d,]+  STREAK 24 '
        $r.TakeGameSounds() | Should -Not -Contain 'Heart'
        Complete-GameTest $r 'A.25' -Result 'Passed'
        $popup = $false
        for ($i = 0; $i -lt 160; $i++) {
            Invoke-GameCourse $r -Seconds 0.05 -Width 165 -Height 52
            if (($r.GetPlainScreen(165, 52) -join "`n") -match '♥ \+1') { $popup = $true }
        }
        $popup | Should -BeTrue
        @(Get-GameCourse $r)[0].Hearts | Should -Be 2
        (Get-GameTopLine $r.GetPlainScreen(165, 52)) | Should -Match '^ MAESTER RUN  ♥ ♥ ♡  SCORE [\d,]+  STREAK 25 '
        @($r.TakeGameSounds() | Where-Object { $_ -eq 'Heart' }).Count | Should -Be 1
        # And the next one at fifty.
        1..25 | ForEach-Object { Complete-GameTest $r "B.$_" -Result 'Passed'; Invoke-GameCourse $r -Seconds 0.5 -Width 165 -Height 52 }
        Invoke-GameCourse $r -Seconds 8 -Width 165 -Height 52
        @(Get-GameCourse $r)[0].Hearts | Should -Be 3
        @($r.TakeGameSounds() | Where-Object { $_ -eq 'Heart' }).Count | Should -Be 1
        # The hearts are red, and the ones that are gone are not.
        Complete-GameTest $r 'F.3' -Severity 'Critical'
        Wait-GameHit $r 3 | Should -BeTrue
        $r.Stop()
        $frame = $t.Writer.ToString()
        # (In the band of this screen they are sprites: two that are left, and one that is gone.)
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;1;38;5;196m▟▙▟▙$esc[0m  $esc[0;1;38;5;196m▟▙▟▙$esc[0m  $esc[0;38;5;240m╭╮╭╮"))
        $r.Close()
    }

    It 'Is over when the last heart is gone: a card with the score, and Enter for another game of what is left of the run' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 20
        $r = $t.Renderer
        $r.GameBestPath = Join-Path $TestDrive 'over/run-best.txt'
        Send-GameText $r 'dead'
        # A game of six coins, and then three hits.
        1..6 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Invoke-GameCourse $r -Seconds 12 -Width 165 -Height 52
        $r.GameScore | Should -Be 3000
        $null = $r.TakeGameSounds()
        1..3 | ForEach-Object { Complete-GameTest $r "F.$_" -Severity 'Critical' -Title 'A failed test' }
        Wait-GameHit $r 2 | Should -BeTrue
        @(Get-GameCourse $r)[0].State | Should -Not -Be 'over'
        Wait-GameHit $r 3 | Should -BeTrue
        @(Get-GameCourse $r)[0].State | Should -Be 'over'
        @(Get-GameCourse $r)[0].Hearts | Should -Be 0
        # The last hit sounds as the end of the game, and the runner goes down before the card is up.
        $r.TakeGameSounds() | Should -Be @('Hit', 'Hit', 'Death')
        $r.AdvanceGame(0.2)
        $screen = $r.GetPlainScreen(165, 52)
        ($screen -join "`n") | Should -Not -Match 'GAME OVER'
        (Get-GameTopLine $screen) | Should -Match '^ MAESTER RUN  ♡ ♡ ♡  SCORE 3,000  STREAK 0 '
        Send-GameKey $r Enter
        @(Get-GameCourse $r)[0].State | Should -Be 'over'
        $r.AdvanceGame(0.3)
        $screen = $r.GetPlainScreen(165, 52)
        $ground = @(2..49 | Where-Object { $screen[$_].StartsWith('▔▔▔') })[0]
        $screen[$ground - 1].PadRight(40).Substring(0, 40) | Should -Match '▁▂▃▂▁'
        ($screen[2..($ground - 1)] -join "`n") | Should -Not -Match '▐███▌'
        $r.AdvanceGame(0.3)
        $card = $r.GetPlainScreen(165, 52)
        $text = $card -join "`n"
        $text | Should -Match '│ +GAME OVER +│'
        $text | Should -Match '│ +SCORE 3,000 of 10,000 +│'
        $text | Should -Match '│ +6 coins · 0 stomps · best streak 6 · 3 hits +│'
        $text | Should -Match '│ +in the game only: 3 still need you for real +│'
        $text | Should -Match '│ +Enter  play again     Esc  dashboard +│'
        $card[51] | Should -Match '^ Enter play again +M sound on   Esc back to the dashboard $'
        $card[50] | Should -Match '^ ✗ Hit by F\.\d A failed test '
        # Nothing moves, and no key of the game does anything: not the jump, and not the pause.
        $course = $r.GetGameCourse() -join '|'
        Send-GameKey $r Spacebar
        Send-GameText $r 'pw'
        $r.AdvanceGame(3)
        $r.GetGameCourse() -join '|' | Should -Be $course
        $r.GetPlainScreen(165, 52) | Should -Be $card
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        # The sound can be turned off and on, and the dashboard is a key away: the card is there when the game is back.
        Send-GameText $r 'm'
        $r.GetPlainScreen(165, 52)[51] | Should -Match '^ Enter play again +M sound off   Esc back to the dashboard $'
        Send-GameText $r 'm'
        Send-GameKey $r Escape
        $r.IsGameShown | Should -BeFalse
        # The run goes on, and its results wait for the next game.
        1..2 | ForEach-Object { Complete-GameTest $r "Q.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match '│ +GAME OVER +│'
        $r.GetGameCourse() -join '|' | Should -Be $course
        $result = $r.GameResult
        $result.Score | Should -Be 3000
        $result.Games | Should -Be 1

        # Enter: a new game, with three hearts and no points. The run is still what the score is a share of.
        Send-GameKey $r Enter
        $screen = $r.GetPlainScreen(165, 52)
        ($screen -join "`n") | Should -Not -Match 'GAME OVER'
        (Get-GameTopLine $screen) | Should -Match (Get-GameHud)
        $screen[51] | Should -Match '^ Space jump '
        $now = @(Get-GameCourse $r)
        $now.Count | Should -Be 1
        $now[0].Hearts | Should -Be 3
        $now[0].State | Should -Be 'stands'
        # What came while the card was up is on its course, and nothing of before.
        Invoke-GameCourse $r -Seconds 8 -Width 165 -Height 52
        (Get-GameTopLine $r.GetPlainScreen(165, 52)) | Should -Match (Get-GameHud -Score '1,000' -Streak 2)
        # The result of the run is its best game: the first one.
        $result = $r.GameResult
        $result.Games | Should -Be 2
        $result.Score | Should -Be 3000
        $result.Coins | Should -Be 6
        $result.Hits | Should -Be 3
        $result.BestStreak | Should -Be 6
        $result.Tests | Should -Be 20
        $r.GameScore | Should -Be 3000

        # The second game is over as well, and the run ends while its card is up: the card of the run takes its place.
        1..3 | ForEach-Object { Complete-GameTest $r "G.$_" -Severity 'Critical' }
        Wait-GameHit $r 6 | Should -BeFalse
        for ($i = 0; $i -lt 600 -and @(Get-GameCourse $r)[0].State -ne 'over'; $i++) { $r.AdvanceGame(0.025) }
        $r.AdvanceGame(1)
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'GAME OVER'
        $null = $r.TakeGameSounds()
        $r.Stop()
        $r.TakeGameSounds() | Should -Be @('Finish')
        $card = $r.GetPlainScreen(165, 52)
        $text = $card -join "`n"
        $text | Should -Not -Match 'GAME OVER'
        $text | Should -Match '│ +RUN COMPLETE +│'
        $text | Should -Match '│ +SCORE 3,000 of 10,000 +│'
        $text | Should -Match '│ +6 coins · 0 stomps · best streak 6 · 3 hits +│'
        $text | Should -Match '│ +the best of 2 games +│'
        $text | Should -Match '│ +in the game only: 6 still need you for real +│'
        $card[51] | Should -Match '^ +Esc back to the dashboard $'
        # Enter does nothing any more.
        Send-GameKey $r Enter
        $r.GetPlainScreen(165, 52) | Should -Be $card
        $r.Close()
        # The best game of the run is what is kept as the best score.
        $r.SaveGameBest() | Should -BeTrue
        (Get-Content -LiteralPath $r.GameBestPath -Raw) | Should -Match '^3000 \d{4}-\d\d-\d\d\n$'
        $r.GameResult.NewBest | Should -BeTrue
        $r.GameResult.Score | Should -Be 3000
    }

    It 'Starts a new game with a higher score than the one before it as the best of the run' {
        $t = New-GameDashboard -Total 10
        $r = $t.Renderer
        Send-GameText $r 'dead'
        # A game of one coin, and three hits.
        Complete-GameTest $r 'P.1' -Result 'Passed'
        $r.AdvanceGame(5)
        1..3 | ForEach-Object { Complete-GameTest $r "F.$_" -Severity 'Critical' }
        Wait-GameHit $r 3 | Should -BeTrue
        $r.GameResult.Score | Should -Be 1000
        # Enter is a key of the keyboard, as a character too.
        $r.AdvanceGame(1)
        $r.SendKey([ConsoleKey]0, [char]13)
        @(Get-GameCourse $r)[0].State | Should -Be 'stands'
        $r.GameResult.Games | Should -Be 2
        $r.GameResult.Score | Should -Be 1000
        # The second game is the better one: three coins.
        1..3 | ForEach-Object { Complete-GameTest $r "Q.$_" -Result 'Passed'; $r.AdvanceGame(5) }
        $result = $r.GameResult
        $result.Score | Should -Be 3000
        $result.Coins | Should -Be 3
        $result.Hits | Should -Be 0
        $result.Games | Should -Be 2
        $r.Stop()
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Match 'SCORE 3,000 of 10,000'
        $r.Close()
    }

    It 'Opens a card of help on ?, H or F1, under which the game stands still, and closes it on any key' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        Complete-GameTest $r 'F.1' -Severity 'Low'
        Send-GameText $r 'dead'
        $r.AdvanceGame(0.5)
        $r.GetPlainScreen(165, 52)[51] | Should -Match '   M sound on   \? help   Esc back to the dashboard +$'
        $null = $r.TakeGameSounds()
        $opens = { Send-GameText $r '?' }, { Send-GameText $r 'h' }, { Send-GameText $r 'H' }, { Send-GameKey $r F1 }
        $closes = { Send-GameKey $r Spacebar }, { Send-GameKey $r Escape }, { Send-GameText $r 'p' }, { Send-GameText $r '?' }
        foreach ($i in 0..3) {
            $before = $r.GetGameCourse() -join '|'
            & $opens[$i]
            $text = $r.GetPlainScreen(165, 52) -join "`n"
            # What the game is, that 10,000 is the most, and the keys.
            $text | Should -Match '│  MAESTER RUN +│'
            $text | Should -Match "│  You found it\. This course is built live from your tenant's test results\.  │"
            $text | Should -Match '│    ▗█▖ Failed tests come at you\. Land on them to squash them\. +│'
            $text | Should -Match '│        \(Sadly, that only fixes them in here\.\) +│'
            $text | Should -Match '│     ●  Passed tests are coins\. A streak of them builds a bridge\. +│'
            $text | Should -Match '│     ♥  Three hits and you are out\. +│'
            $text | Should -Match '│    ▐▓▌ DC01 waits near the end\. Decommission it\. +│'
            $text | Should -Match '│  The better your tenant, the higher you can score\. +│'
            $text | Should -Match '│  A perfect run on a perfect tenant is 10,000\. Bragging rights only\. +│'
            $text | Should -Match '│    Space  jump, and again in the air       M    sound on/off +│'
            $text | Should -Match '│    P      pause                            Esc  back to the dashboard +│'
            $text | Should -Match '│    \?      this help +│'
            $text | Should -Match '│ +press any key to get back to it +│'
            # The game stands still under it.
            $r.AdvanceGame(3)
            $r.GetGameCourse() -join '|' | Should -Be $before
            # Any key closes it, and does nothing else: no jump, no pause, and Esc does not leave the game.
            & $closes[$i]
            $r.IsGameShown | Should -BeTrue
            $text = $r.GetPlainScreen(165, 52) -join "`n"
            $text | Should -Not -Match 'You found it|PAUSED'
            $r.GetGameCourse() -join '|' | Should -Be $before
            $r.TakeGameSounds() | Should -BeNullOrEmpty
            # And the game goes on.
            $r.AdvanceGame(0.1)
            $r.GetGameCourse() -join '|' | Should -Not -Be $before
        }
        # The signs before the lines have the colours of what they stand for: a creature, a coin, a heart.
        Send-GameText $r '?'
        $r.ItemFinished('Passed')
        $frame = $t.Writer.ToString()
        $frame = $frame.Substring($frame.LastIndexOf("$esc[H"))
        $frame | Should -Match ([regex]::Escape("$esc[0;38;5;208m▗█▖"))
        $frame | Should -Match ([regex]::Escape("$esc[0;1;33m●"))
        $frame | Should -Match ([regex]::Escape("$esc[0;1;31m♥"))
        $frame | Should -Match ([regex]::Escape("$esc[0;1mSpace"))
        Send-GameText $r 'x'
        # A game that is paused is still paused when the help is closed.
        Send-GameText $r 'p'
        Send-GameText $r '?'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'You found it'
        Send-GameText $r 'x'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'PAUSED'
        Send-GameText $r 'p'
        # When the tests stop the help gives way to the card of the run, and there is none after that.
        Send-GameText $r '?'
        $r.Stop()
        $text = $r.GetPlainScreen(165, 52) -join "`n"
        $text | Should -Match 'RUN COMPLETE'
        $text | Should -Not -Match 'You found it'
        Send-GameText $r '?'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Not -Match 'You found it'
        $r.Close()
    }

    It 'Fits the card of help on the smallest screen of the game, in ASCII as well' {
        foreach ($asciiOnly in $false, $true) {
            $t = New-GameDashboard -Ascii:$asciiOnly
            $r = $t.Renderer
            Send-GameText $r 'dead'
            $r.GetPlainScreen(80, 24)[23] | Should -Match '^ Space jump, twice in the air   P pause +M sound on   \? help   Esc dashboard $'
            Send-GameText $r '?'
            $screen = $r.GetPlainScreen(80, 24)
            $screen.Count | Should -Be 24
            foreach ($line in $screen) { $line.Length | Should -BeLessThan 80 }
            # All of it is between the rows of the run and the rows of the keys.
            $corner = if ($asciiOnly) { '\+-{70,}\+' } else { '╭─{70,}╮' }
            $top = @(0..23 | Where-Object { $screen[$_] -match $corner })[0]
            $top | Should -BeGreaterThan 1
            $bottom = @(0..23 | Where-Object { $screen[$_] -match $(if ($asciiOnly) { '\+-{70,}\+' } else { '╰─{70,}╯' }) })[-1]
            $bottom | Should -Be ($top + 18)
            $bottom | Should -BeLessThan 22
            $text = $screen -join "`n"
            $text | Should -Match "You found it\. This course is built live from your tenant's test results\."
            $text | Should -Match 'Three hits and you are out\.'
            $text | Should -Match 'DC01 waits near the end\. Decommission it\.'
            $text | Should -Match 'A perfect run on a perfect tenant is 10,000\. Bragging rights only\.'
            $text | Should -Match 'Space  jump, and again in the air       M    sound on/off'
            $text | Should -Match 'P      pause                            Esc  back to the dashboard'
            $text | Should -Match 'press any key to get back to it'
            if ($asciiOnly) {
                foreach ($line in $screen) { $line | Should -Match '^[\x20-\x7E]*$' }
                $text | Should -Match ([regex]::Escape('/^\ Failed tests'))
                $text | Should -Match ' o  Passed tests'
                $text | Should -Match ' \*  Three hits'
            }
            $r.Close()
        }
    }

    It 'Breaks through the dashboard the first time the game is put on screen in a run: cracks, and a hole that grows' {
        $new = {
            param([int] $Seed = 7, [switch] $AtOnce, [switch] $Ascii)
            $t = New-GameDashboard -Width 165 -Height 52 -Seed $Seed -Opening:(-not $AtOnce) -Ascii:$Ascii
            1..5 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
            Complete-GameTest $t.Renderer 'F.1' -Severity 'Low'
            $t
        }
        # The game as it is behind the wall: the same game, put on screen at once.
        $t = & $new -AtOnce
        Send-GameText $t.Renderer 'dead'
        $game = $t.Renderer.GetPlainScreen(165, 52) | ForEach-Object { $_.PadRight(164) }
        $t.Renderer.Close()

        $t = & $new
        $r = $t.Renderer
        # The wall is the dashboard as it is when the word is typed.
        $dashboard = $r.GetPlainScreen(165, 52) | ForEach-Object { $_.PadRight(164) }
        Send-GameText $r 'dead'
        $r.IsGameShown | Should -BeTrue
        $r.IsGameOpening | Should -BeTrue
        # The sound of it is asked for once.
        $r.TakeGameSounds() | Should -Be @('Break')
        # The first frame is the dashboard as it was.
        $frame = { $r.GetPlainScreen(165, 52) | ForEach-Object { $_.PadRight(164) } }
        $first = & $frame
        $first.Count | Should -Be 52
        $first | Should -Be $dashboard
        # What a frame is made of: cells of the dashboard, cells of the game, and what is neither.
        $parts = {
            param([string[]] $Screen)
            $wall = 0; $hole = 0; $other = [System.Text.StringBuilder]::new()
            # (Not the rows of the band at the top of the game: they have the time the run still takes, which is of the clock.)
            foreach ($y in 5..51) {
                for ($x = 0; $x -lt 164; $x++) {
                    $c = $Screen[$y][$x]
                    if ($c -eq $dashboard[$y][$x]) { if ($c -ne $game[$y][$x]) { $wall++ } }
                    elseif ($c -eq $game[$y][$x]) { $hole++ }
                    else { $null = $other.Append($c) }
                }
            }
            [pscustomobject]@{ Wall = $wall; Hole = $hole; Other = $other.ToString() }
        }
        # For a moment there are cracks in it, and nothing else: the game is not seen yet.
        $r.AdvanceGame(0.3)
        $r.IsGameOpening | Should -BeTrue
        $cracked = & $parts (& $frame)
        $cracked.Other.Length | Should -BeGreaterThan 40
        $cracked.Other | Should -Match '^[-/\\|]+$'
        $cracked.Hole | Should -BeLessThan 40
        # Then the hole: in the middle of the breaking a part of the screen is the dashboard still, a part
        # is the game, and between the two is the rubble of the edge. What is not the dashboard, the
        # rubble or a crack is the game.
        $r.AdvanceGame(0.5)
        $middle = & $parts (& $frame)
        $middle.Wall | Should -BeGreaterThan 500
        $middle.Hole | Should -BeGreaterThan 100
        $middle.Other | Should -Match '^[-/\\|▓▒░]+$'
        ([regex]::Matches($middle.Other, '[▓▒░]')).Count | Should -BeGreaterThan 30
        # The hole grows.
        $r.AdvanceGame(0.3)
        $late = & $parts (& $frame)
        $late.Hole | Should -BeGreaterThan ($middle.Hole * 1.5)
        $late.Wall | Should -BeLessThan $middle.Wall
        # The game did not move behind it: the creature of the failed test is not on its course yet.
        @(Get-GameCourse $r).Count | Should -Be 1
        # After 1.3 seconds the dashboard is gone: the frame is the game, with the splash on it at once
        # and the tune of the start.
        $r.AdvanceGame(0.2)
        $r.IsGameOpening | Should -BeFalse
        $r.IsGameSplash | Should -BeTrue
        $r.TakeGameSounds() | Should -Be @('Intro')
        $last = & $frame
        $last[0..3] | Should -Be $game[0..3]
        $last[48..51] | Should -Be $game[48..51]
        ($last -join "`n") | Should -Match 'press any key to start'
        # A key, and the game moves.
        Send-GameKey $r Enter
        $r.IsGameSplash | Should -BeFalse
        $r.AdvanceGame(1)
        @(Get-GameCourse $r 'Biter')[0].X | Should -BeLessThan 125

        # Only the first time in a run: after that the game is on screen at once, with no sound of a wall.
        Send-GameKey $r Escape
        Send-GameText $r 'dead'
        $r.IsGameShown | Should -BeTrue
        $r.IsGameOpening | Should -BeFalse
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Not -Match 'Welcome'
        $r.Close()

        # The frames of the wall are written with the colours of the dashboard, and without its hyperlinks.
        $t = & $new
        $r = $t.Renderer
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$([char]27)]8;;https://maester.dev"))
        Start-GameBreak $r
        $r.AdvanceGame(0.7)
        $r.ItemFinished('Passed')
        $written = $t.Writer.ToString()
        $written = $written.Substring($written.LastIndexOf("$esc[H"))
        $written | Should -Not -Match ([regex]::Escape("$([char]27)]8;;"))
        $written | Should -Match ([regex]::Escape("$esc[0;38;5;245m") + '[▓▒░]')
        $written | Should -Match ([regex]::Escape("$esc[0;1;97m") + '[-/\\|]')
        $written | Should -Match 'maester\.dev'
        # When the tests stop while it breaks, the card of the run is what is shown.
        $r.Stop()
        $r.IsGameOpening | Should -BeFalse
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'RUN COMPLETE'
        $r.Close()

        # Without Unicode the rubble is ASCII as well.
        $t = & $new -Ascii
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($line in $r.GetPlainScreen(165, 52)) { $line | Should -Match '^[\x20-\x7E]*$' }
        Send-GameText $r 'y'
        foreach ($line in $r.GetPlainScreen(165, 52)) { $line | Should -Match '^[\x20-\x7E]*$' }
        $r.AdvanceGame(0.7)
        foreach ($step in 1..13) {
            $r.AdvanceGame(0.1)
            foreach ($line in $r.GetPlainScreen(165, 52)) { $line | Should -Match '^[\x20-\x7E]*$' }
        }
        $r.IsGameOpening | Should -BeFalse
        $r.Close()
    }

    It 'Breaks the same wall the same way for the same seed, and ends the breaking at once on any key' {
        $frames = {
            param([int] $Seed)
            $t = New-GameDashboard -Width 124 -Height 38 -Seed $Seed -Opening
            1..5 | ForEach-Object { $t.Renderer.ItemFinished('Passed') }
            Start-GameBreak $t.Renderer
            foreach ($step in 1..12) {
                $t.Renderer.AdvanceGame(0.1)
                # (The first row of the game has the time the run still takes, which is of the clock.)
                $t.Renderer.GetPlainScreen(124, 38)[1..37] -join "`n"
            }
            $t.Renderer.Close()
        }
        $one = & $frames 7
        $same = & $frames 7
        $other = & $frames 8
        $same | Should -Be $one
        $other[5] | Should -Not -Be $one[5]
        @($one | Select-Object -Unique).Count | Should -Be 12

        # A key while it breaks: the wall is gone, and the key did nothing else.
        $t = New-GameDashboard -Opening
        $r = $t.Renderer
        Start-GameBreak $r
        $r.AdvanceGame(0.4)
        $r.IsGameOpening | Should -BeTrue
        Send-GameKey $r Spacebar
        $r.IsGameOpening | Should -BeFalse
        $r.IsGameShown | Should -BeTrue
        # The splash is up at once, with its tune.
        $r.TakeGameSounds() | Should -Be @('Break', 'Intro')
        @(Get-GameCourse $r)[0].State | Should -Be 'stands'
        # The splash is still to come.
        $r.IsGameSplash | Should -BeTrue
        # Esc is such a key as well: the game stays.
        $r.Close()
        $t = New-GameDashboard -Opening
        Start-GameBreak $t.Renderer
        Send-GameKey $t.Renderer Escape
        $t.Renderer.IsGameOpening | Should -BeFalse
        $t.Renderer.IsGameShown | Should -BeTrue
        $t.Renderer.Close()
    }

    It 'Shows a splash the first time, as soon as the wall is gone: the card of the help, with a key to start, and the tune of the start' {
        $t = New-GameDashboard -Width 165 -Height 52 -Opening
        $r = $t.Renderer
        Start-GameBreak $r
        $r.AdvanceGame(1.2)
        $r.IsGameSplash | Should -BeFalse
        $null = $r.TakeGameSounds()
        $r.AdvanceGame(0.1)
        $r.IsGameOpening | Should -BeFalse
        $r.IsGameSplash | Should -BeTrue
        $r.TakeGameSounds() | Should -Be @('Intro')
        $screen = $r.GetPlainScreen(165, 52)
        $text = $screen -join "`n"
        # The card of the help, with a last line that says how to start.
        $help = @(Get-GameCardText $screen)
        $help[0] | Should -Match '^MAESTER RUN'
        $help | Should -Contain "You found it. This course is built live from your tenant's test results."
        $help[-1] | Should -Match '^ *press any key to start *$'
        $text | Should -Not -Match 'press any key to get back to it'
        # Nothing else is written on it, and the counter of the run is behind it as under the help.
        $text | Should -Not -Match 'Welcome|DEcommissioning'
        $text | Should -Match 'tests completed'
        # The game waits under it, as long as it takes.
        $course = @(Get-GameCourse $r) | ConvertTo-Json -Compress
        $r.AdvanceGame(10)
        (@(Get-GameCourse $r) | ConvertTo-Json -Compress) | Should -Be $course
        $r.IsGameSplash | Should -BeTrue
        # M changes the sound and leaves it up; Esc goes back to the dashboard, and the splash is there again after the word.
        Send-GameText $r 'm'
        $r.IsGameSplash | Should -BeTrue
        Send-GameText $r 'm'
        Send-GameKey $r Escape
        $r.IsGameShown | Should -BeFalse
        Send-GameText $r 'dead'
        $r.IsGameSplash | Should -BeTrue
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'press any key to start'
        # Any other key starts the game and does nothing else: no jump.
        Send-GameKey $r Spacebar
        $r.IsGameSplash | Should -BeFalse
        $r.TakeGameSounds() | Should -Not -Contain 'Jump'
        $text = $r.GetPlainScreen(165, 52) -join "`n"
        $text | Should -Not -Match 'Welcome|press any key'
        $text | Should -Match 'tests completed'
        # The help is the same card, with its own last line.
        Send-GameText $r '?'
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Match 'press any key to get back to it'
        Send-GameKey $r Spacebar
        # Not a second time in the run.
        Send-GameKey $r Escape
        Send-GameText $r 'dead'
        $r.AdvanceGame(2)
        $r.IsGameSplash | Should -BeFalse
        ($r.GetPlainScreen(165, 52) -join "`n") | Should -Not -Match 'Welcome|press any key'
        $r.Close()

        # A key while the wall breaks ends it, and the splash is up at once. On the smallest screen, and
        # without colour or Unicode, it is the card of the help as well, in ASCII.
        $t = New-GameDashboard -Opening -Ascii -NoColor
        $r = $t.Renderer
        Start-GameBreak $r
        $r.AdvanceGame(0.4)
        Send-GameKey $r Spacebar
        $r.IsGameSplash | Should -BeTrue
        $screen = $r.GetPlainScreen(80, 24)
        ($screen -join "`n") | Should -Match 'press any key to start'
        foreach ($line in $screen) { $line | Should -Match '^[\x20-\x7E]*$' }
        Send-GameKey $r Spacebar
        ($r.GetPlainScreen(80, 24) -join "`n") | Should -Not -Match 'Welcome|press any key'
        $t.Writer.ToString() | Should -Not -Match "$esc\[[\d;]*m"
        $r.Close()

        # Muted, there is no tune.
        $t = New-GameDashboard -Opening
        $r = $t.Renderer
        Start-GameBreak $r
        $r.AdvanceGame(0.4)
        Send-GameText $r 'm'
        $null = $r.TakeGameSounds()
        $r.AdvanceGame(1.5)
        $r.IsGameSplash | Should -BeTrue
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.Close()
    }

    It 'Asks for a sound for a jump, a second jump, a coin, a stomp, a snap, a hit, every ten of a streak and the end of the run' {
        $t = New-GameDashboard -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        # The jump and the second jump, once each: a third key in the air is silent.
        Send-GameKey $r Spacebar
        $r.TakeGameSounds() | Should -Be @('Jump')
        $r.AdvanceGame(0.3)
        Send-GameKey $r Spacebar
        Send-GameKey $r Spacebar
        $r.TakeGameSounds() | Should -Be @('DoubleJump')
        # They are taken once.
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.AdvanceGame(2)
        $r.TakeGameSounds() | Should -BeNullOrEmpty

        # A coin, when it is collected and not before.
        Complete-GameTest $r 'P.1' -Result 'Passed'
        $r.AdvanceGame(1)
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.AdvanceGame(3)
        $r.TakeGameSounds() | Should -Be @('Coin')
        # A stomp, with the snap of the mouth that opened and the jump that answered it.
        Complete-GameTest $r 'F.1' -Severity 'Low'
        Invoke-GameStomp $r
        $r.TakeGameSounds() | Should -Be @('Snap', 'Jump', 'Stomp')
        # A hit, after the snap of the mouth that opened to lunge.
        Complete-GameTest $r 'F.2' -Severity 'Low'
        $r.AdvanceGame(5)
        $r.TakeGameSounds() | Should -Be @('Snap', 'Hit')

        # The tenth pick-up of a streak, and the twentieth: one sound each, with the coin.
        foreach ($n in 1..21) { Complete-GameTest $r "S.$n" -Result 'Passed'; Invoke-GameCourse $r -Seconds 0.5 }
        Invoke-GameCourse $r -Seconds 6
        $r.GameResult.BestStreak | Should -Be 21
        $sounds = $r.TakeGameSounds()
        @($sounds | Where-Object { $_ -eq 'Coin' }).Count | Should -Be 21
        @($sounds | Where-Object { $_ -eq 'Streak' }).Count | Should -Be 2
        $coins = 0
        $at = foreach ($sound in $sounds) { if ($sound -eq 'Coin') { $coins++ } elseif ($sound -eq 'Streak') { $coins } }
        $at | Should -Be @(9, 19)
        $sounds | Where-Object { $_ -notin 'Coin', 'Streak', 'Jump' } | Should -BeNullOrEmpty

        # The end of the run, once, when the tests stop with the game on screen.
        $r.Stop()
        $r.TakeGameSounds() | Should -Be @('Finish')
        $r.AdvanceGame(1)
        Send-GameKey $r Spacebar
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.Close()
    }

    It 'Writes each key of the key row in one colour of text, with the keys in a group at each edge' {
        $t = New-GameDashboard -Width 165 -Height 52
        $r = $t.Renderer
        $r.TrueColor = $true
        Send-GameText $r 'dead'
        $r.AdvanceGame(0.1)
        $keys = $r.GetPlainScreen(165, 52)[-1]
        $keys | Should -Match '^ Space jump   Space again in the air: double jump   P pause {20,}M sound on   \? help   Esc back to the dashboard $'
        $t.Writer.GetStringBuilder().Clear() > $null
        $r.ShowStatus($null)
        $frame = $t.Writer.ToString()
        # The last row as it was written: each key has one colour of text from its first letter to its last,
        # though the bar under it goes from red to amber.
        $row = @($frame -split "`n" | Where-Object { ($_ -replace "$esc\[[0-9;]*m", '') -match 'Esc back to the dashboard' })[-1]
        foreach ($k in 'Space again in the air: double jump', 'Esc back to the dashboard', 'M sound on') {
            $start = ($row -replace "$esc\[[0-9;]*m", '').IndexOf($k)
            $colours = [System.Collections.Generic.HashSet[string]]::new()
            $plain = 0
            $current = $null
            foreach ($m in [regex]::Matches($row, "$esc\[([0-9;]*)m|.")) {
                if ($m.Groups[1].Success) { $current = $m.Groups[1].Value; continue }
                if ($plain -ge $start -and $plain -lt $start + $k.Length -and $m.Value -ne ' ') { $null = $colours.Add(($current -replace ';48;2;.*$', '')) }
                $plain++
            }
            $colours.Count | Should -Be 1 -Because "the key '$k' has one colour of text"
        }
        $r.Close()
    }

    It 'Asks for no sound while the game is muted with M, paused or off screen, and says in the key row whether it is muted' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $r.GetPlainScreen(165, 52)[51] | Should -Match '   M sound on   '
        Send-GameKey $r Spacebar
        @($r.TakeGameSounds()).Count | Should -Be 1
        $r.AdvanceGame(1)

        # Muted: the game goes on, and nothing is asked for.
        Send-GameText $r 'm'
        $r.GetPlainScreen(165, 52)[51] | Should -Match '^ Space jump   Space again in the air: double jump   P pause +M sound off   \? help   Esc back to the dashboard $'
        Complete-GameTest $r 'P.1' -Result 'Passed'
        Send-GameKey $r Spacebar
        $r.AdvanceGame(9)
        $r.GameResult.Coins | Should -Be 1
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        Send-GameText $r 'M'
        $r.GetPlainScreen(165, 52)[51] | Should -Match '   M sound on   '
        Send-GameKey $r Spacebar
        $r.TakeGameSounds() | Should -Be @('Jump')
        $r.AdvanceGame(1)

        # Paused: nothing moves, so nothing sounds.
        Send-GameText $r 'p'
        Send-GameKey $r Spacebar
        $r.AdvanceGame(2)
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        Send-GameText $r 'p'

        # Off screen: the dashboard is silent, and so is the end of a run whose game is not on screen.
        Send-GameKey $r Escape
        Complete-GameTest $r 'P.2' -Result 'Passed'
        $r.AdvanceGame(9)
        Send-GameKey $r Spacebar
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.Stop()
        $r.TakeGameSounds() | Should -BeNullOrEmpty
        $r.Close()

        # A game that is muted, or paused, says nothing when the tests stop either.
        foreach ($key in 'm', 'p') {
            $t = New-GameDashboard
            Send-GameText $t.Renderer "dead$key"
            $t.Renderer.Stop()
            $t.Renderer.TakeGameSounds() | Should -BeNullOrEmpty
            $t.Renderer.Close()
        }
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

    It 'Makes the sound <Name> in memory as a WAV file of <Seconds> seconds: 16-bit mono, a quarter of full scale' -ForEach @(
        @{ Name = 'Jump'; Seconds = 0.12 }, @{ Name = 'DoubleJump'; Seconds = 0.11 }, @{ Name = 'Coin'; Seconds = 0.18 }, @{ Name = 'Stomp'; Seconds = 0.16 },
        @{ Name = 'Hit'; Seconds = 0.32 }, @{ Name = 'Streak'; Seconds = 0.22 }, @{ Name = 'Finish'; Seconds = 0.6 }, @{ Name = 'Death'; Seconds = 0.57 },
        @{ Name = 'Heart'; Seconds = 0.24 }, @{ Name = 'Snap'; Seconds = 0.1 }, @{ Name = 'Break'; Seconds = 0.595 }, @{ Name = 'Down'; Seconds = 0.8 }
    ) {
        $wave = [Maester.Engine.MtConsoleRenderer]::GetGameSound($Name)
        $text = { param($at) [System.Text.Encoding]::ASCII.GetString($wave, $at, 4) }
        # The header of a WAV file with PCM in it: RIFF, the size of what follows, WAVE, a format of 16 bytes, the samples.
        & $text 0 | Should -Be 'RIFF'
        [BitConverter]::ToInt32($wave, 4) | Should -Be ($wave.Length - 8)
        & $text 8 | Should -Be 'WAVE'
        & $text 12 | Should -Be 'fmt '
        [BitConverter]::ToInt32($wave, 16) | Should -Be 16
        [BitConverter]::ToInt16($wave, 20) | Should -Be 1      # PCM
        [BitConverter]::ToInt16($wave, 22) | Should -Be 1      # one channel
        [BitConverter]::ToInt32($wave, 24) | Should -Be 22050  # samples a second
        [BitConverter]::ToInt32($wave, 28) | Should -Be 44100  # bytes a second
        [BitConverter]::ToInt16($wave, 32) | Should -Be 2      # bytes a sample
        [BitConverter]::ToInt16($wave, 34) | Should -Be 16     # bits a sample
        & $text 36 | Should -Be 'data'
        [BitConverter]::ToInt32($wave, 40) | Should -Be ($wave.Length - 44)
        $samples = @(for ($i = 44; $i -lt $wave.Length; $i += 2) { [BitConverter]::ToInt16($wave, $i) })
        [math]::Abs($samples.Count / 22050 - $Seconds) | Should -BeLessThan 0.001
        # Not silent, and no louder than a quarter of what 16 bits hold. It starts and ends at nothing, so that it does not click.
        $loudest = ($samples | ForEach-Object { [math]::Abs($_) } | Measure-Object -Maximum).Maximum
        $loudest | Should -BeGreaterThan 7000
        $loudest | Should -BeLessOrEqual 8192
        @($samples | Where-Object { [math]::Abs($_) -gt 2000 }).Count | Should -BeGreaterThan ($samples.Count / 4)
        $samples[0] | Should -Be 0
        $samples[-1] | Should -Be 0
        # The same every time, and a copy: what a caller does to it does not change the sound.
        $wave[100] = 99
        $again = [Maester.Engine.MtConsoleRenderer]::GetGameSound($Name)
        $again[100] | Should -Not -Be 99
        [Convert]::ToBase64String($again) | Should -Be ([Convert]::ToBase64String([Maester.Engine.MtConsoleRenderer]::GetGameSound($Name)))
    }

    It 'Has thirteen sounds, each its own: a jump that goes up, and an end of the game that goes down' {
        $names = [Maester.Engine.MtConsoleRenderer]::GameSoundNames
        $names | Should -Be @('Jump', 'DoubleJump', 'Coin', 'Stomp', 'Hit', 'Streak', 'Finish', 'Death', 'Heart', 'Snap', 'Break', 'Down', 'Intro')
        [Maester.Engine.MtConsoleRenderer]::GetGameSound('Nothing') | Should -BeNullOrEmpty
        @($names | ForEach-Object { [Convert]::ToBase64String([Maester.Engine.MtConsoleRenderer]::GetGameSound($_)) } | Select-Object -Unique).Count | Should -Be 13
        # The pitch of a square wave is how often it changes sign: the jump ends higher than it starts, and
        # the second jump is higher than the first.
        $turns = {
            param([string] $Name, [double] $From, [double] $To)
            $wave = [Maester.Engine.MtConsoleRenderer]::GetGameSound($Name)
            $count = 0
            $before = 1
            $samples = ($wave.Length - 44) / 2
            for ($i = [int]($samples * $From); $i -lt [int]($samples * $To); $i++) {
                $sign = [math]::Sign([BitConverter]::ToInt16($wave, 44 + 2 * $i))
                if ($sign -ne 0 -and $sign -ne $before) { $count++; $before = $sign }
            }
            $count
        }
        (& $turns 'Jump' 0.5 1) | Should -BeGreaterThan (& $turns 'Jump' 0 0.5)
        (& $turns 'DoubleJump' 0.5 1) | Should -BeGreaterThan (& $turns 'DoubleJump' 0 0.5)
        ((& $turns 'DoubleJump' 0 1) / 0.11) | Should -BeGreaterThan ((& $turns 'Jump' 0 1) / 0.12)
        # The end of a game falls, a heart that comes back rises: fewer turns, and more, in the second half than in the first.
        (& $turns 'Death' 0.5 1) | Should -BeLessThan (& $turns 'Death' 0 0.5)
        (& $turns 'Heart' 0.5 1) | Should -BeGreaterThan (& $turns 'Heart' 0 0.5)
        # DC01 going down is a note that sinks: it turns less and less often.
        (& $turns 'Down' 0.34 0.68) | Should -BeLessThan ((& $turns 'Down' 0 0.34) / 2)
        # A snap is two clicks, with nothing between them.
        $snap = [Maester.Engine.MtConsoleRenderer]::GetGameSound('Snap')
        $between = @(for ($i = [int](22050 * 0.03); $i -lt [int](22050 * 0.05); $i++) { [BitConverter]::ToInt16($snap, 44 + 2 * $i) })
        ($between | Measure-Object -Maximum).Maximum | Should -Be 0
        ($between | Measure-Object -Minimum).Minimum | Should -Be 0
    }

    It 'Has a band of five rows at the top of a screen with the room: the name in letters of blocks, the hearts, the score in large digits, and the run' {
        $t = New-GameDashboard -Width 165 -Height 52 -Total 60
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $screen = $r.GetPlainScreen(165, 52)
        # The name, five rows high.
        @($screen[0..4] | ForEach-Object { $_.Substring(0, 46) }) | Should -Be @(
            ' █   █  █  ███ ███ ███ ███ ███    ███ █ █ █  █'
            ' ██ ██ █ █ █   █    █  █   █ █    █ █ █ █ ██ █'
            ' █ █ █ ███ ██  ███  █  ██  ██     ██  █ █ █ ██'
            ' █   █ █ █ █     █  █  █   █ █    █ █ █ █ █  █'
            ' █   █ █ █ ███ ███  █  ███ █ █    █ █ ███ █  █'
        )
        # Three hearts, two rows high and apart from one another; under them the streak.
        $hearts = $screen[1].IndexOf('▟▙▟▙')
        $screen[1].Substring($hearts, 16) | Should -Be '▟▙▟▙  ▟▙▟▙  ▟▙▟▙'
        $screen[2].Substring($hearts, 16) | Should -Be '▝██▘  ▝██▘  ▝██▘'
        $screen[4].Substring($hearts, 8) | Should -Be 'STREAK 0'
        # The score: the word, the digits in three rows under it, and what it is out of.
        $score = $screen[0].IndexOf('SCORE')
        $score | Should -BeGreaterThan ($hearts + 18)
        @($screen[1..3] | ForEach-Object { $_.Substring($score, 3) }) | Should -Be @('█▀█', '█ █', '▀▀▀')
        $screen[4].Substring($score, 9) | Should -Be 'of 10,000'
        # The run at the right, in two rows; the progress bar under the band; then the playfield.
        $screen[1] | Should -Match ' run 0/60  0%$'
        $screen[2] | Should -Match '  ✓ 0  ✗ 0  ! 0$'
        $screen[1].Length | Should -Be 164
        $screen[5] | Should -Match '^ ─+ FINISH$'
        (Get-GameTopLine $screen) | Should -Match '^ MAESTER RUN  ♥ ♥ ♥  SCORE 0  STREAK 0 '

        # Every digit, and the comma of the thousands: the score is read from its dots.
        1..12 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed'; $null = Invoke-GameBot $r -Seconds 0.7 }
        $null = Invoke-GameBot $r -Seconds 6
        $r.GameResult.Coins | Should -Be 12
        $screen = $r.GetPlainScreen(165, 52)
        (Get-GameTopLine $screen) | Should -Match "^ MAESTER RUN  ♥ ♥ ♥  SCORE 1,800  STREAK $($r.GameResult.BestStreak) "
        @($screen[1..3] | ForEach-Object { $_.PadRight(170).Substring($score, 22).TrimEnd() }) | Should -Be @('▄█     █▀█ █▀█ █▀█', ' █   ▄ █▀█ █ █ █ █', '▀▀▀ ▀  ▀▀▀ ▀▀▀ ▀▀▀')
        # Nothing in the band moved for it.
        $screen[1].IndexOf('▟▙▟▙') | Should -Be $hearts
        $screen[0].IndexOf('SCORE') | Should -Be $score
        $screen[1] | Should -Match ' run 12/60  20%( +ETA \d+:\d\d)?$'
        $screen[2] | Should -Match '  ✓ 12  ✗ 0  ! 0$'

        # A heart that is gone is an outline, in the place of the one that was there.
        Complete-GameTest $r 'F.1' -Severity 'Critical'
        Wait-GameHit $r 1 | Should -BeTrue
        $screen = $r.GetPlainScreen(165, 52)
        $screen[1].Substring($hearts, 16) | Should -Be '▟▙▟▙  ▟▙▟▙  ╭╮╭╮'
        $screen[2].Substring($hearts, 16) | Should -Be '▝██▘  ▝██▘   ╰╯ '
        (Get-GameTopLine $screen) | Should -Match '^ MAESTER RUN  ♥ ♥ ♡  SCORE [\d,]+  STREAK 0 '
        $r.Close()
    }

    It 'Has the band from 120 columns and 40 rows, and one line on a smaller screen and without Unicode (<Width>x<Height>)' -ForEach @(
        @{ Width = 120; Height = 40; Band = $true }, @{ Width = 124; Height = 40; Band = $true }, @{ Width = 240; Height = 70; Band = $true }
        @{ Width = 119; Height = 40; Band = $false }, @{ Width = 165; Height = 39; Band = $false }, @{ Width = 124; Height = 38; Band = $false }
        @{ Width = 100; Height = 30; Band = $false }, @{ Width = 80; Height = 24; Band = $false }
    ) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 60
        $r = $t.Renderer
        1..7 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        $r.AdvanceGame(1)
        $screen = $r.GetPlainScreen($Width, $Height)
        $screen.Count | Should -Be $Height
        foreach ($line in $screen) { $line.Length | Should -BeLessThan $Width }
        if ($Band) {
            $screen[0] | Should -Match '^ █   █  █  ███ ███ ███ ███ ███    ███ █ █ █  █ .* SCORE$'
            $screen[1] | Should -Match '▟▙▟▙  ▟▙▟▙  ▟▙▟▙ .* run 7/60  11%'
            $screen[5] | Should -Match ' FINISH$'
            $screen[6] | Should -Not -Match 'FINISH'
        } else {
            $screen[0] | Should -Match '^ MAESTER RUN  ♥ ♥ ♥  SCORE 0  STREAK 0 .* ✓ 7  ✗ 0  ! 0$'
            $screen[1] | Should -Match ' FINISH$'
        }
        # The last two rows are the ticker and the keys, whatever the top is.
        $screen[$Height - 2] | Should -Match 'in the game only: nothing needs you for real$'
        $screen[$Height - 1] | Should -Match '^ Space jump'
        $r.Close()

        # Without Unicode it is one line on a screen of any size: the letters of the band are blocks.
        $t = New-GameDashboard -Width $Width -Height $Height -Total 60 -Ascii
        Send-GameText $t.Renderer 'dead'
        $t.Renderer.GetPlainScreen($Width, $Height)[0] | Should -Match '^ MAESTER RUN  \* \* \*  SCORE 0  STREAK 0 '
        $t.Renderer.Close()
    }

    It 'Draws the name of the band in the colours of the wordmark, Maester red to amber, as the terminal has them' {
        $frame = {
            param([switch] $TrueColor, [switch] $NoColor)
            $t = New-GameDashboard -Width 165 -Height 52 -NoColor:$NoColor
            $t.Renderer.TrueColor = [bool]$TrueColor
            Send-GameText $t.Renderer 'dead'
            $written = $t.Writer.ToString()
            $t.Renderer.Close()
            $written.Substring($written.LastIndexOf("$esc[H"))
        }
        # In 24 bits: the first column is the red of the logo, the last one is amber, and a column in
        # between is between them.
        $true24 = & $frame -TrueColor
        $true24 | Should -Match ('^' + [regex]::Escape("[H $esc[0;1;38;2;229;36;59m█"))
        $true24 | Should -Match ([regex]::Escape("$esc[0;1;38;2;255;181;71m█"))
        $true24 | Should -Match ([regex]::Escape("$esc[0;1;38;2;255;10") + '\d;6\dm█')
        # Without them: the nearest of the 216 colours of the cube, from 167 to 221.
        $cube = & $frame
        $cube | Should -Match ('^' + [regex]::Escape("[H $esc[0;1;38;5;167m█"))
        $cube | Should -Match ([regex]::Escape("$esc[0;1;38;5;221m█"))
        $cube | Should -Not -Match '38;2;'
        @([regex]::Matches($cube.Substring(0, $cube.IndexOf('SCORE')), '38;5;(\d+)m') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique).Count | Should -BeGreaterThan 3
        # Without colour the band is its characters, and nothing else.
        $plain = & $frame -NoColor
        $plain | Should -Not -Match "$esc\[[\d;]*m"
        $plain | Should -Match ('^' + [regex]::Escape('[H █   █  █  ███ ███ ███ ███ ███    ███ █ █ █  █'))
    }

    It 'Has the runner in the red of Maester, with a flame over its head that flickers and touches nothing' {
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $seen = @{}
        foreach ($i in 1..18) {
            $r.AdvanceGame(0.04)
            $screen = $r.GetPlainScreen(80, 24)
            $view = Get-GameView $screen
            $seen[($screen[$view.Ground - 5].PadRight(80).Substring($view.X, 5) + '|' + $screen[$view.Ground - 4].PadRight(80).Substring($view.X, 5))] = $true
        }
        # Three ways it is drawn, its tip over its body: it leans back, to the left of the head.
        ($seen.Keys | Sort-Object) | Should -Be (@(' ▗   | ▟▙  ', '▗    | ▜▙  ', ' ▖   |▗█▖  ') | Sort-Object)
        # In colour: the runner in the red of the logo, the nearest of 256 colours or the red itself; the
        # tip of the flame yellow, and under it orange and red.
        $r.ItemFinished('Skipped')
        $frame = $t.Writer.ToString()
        $frame = $frame.Substring($frame.LastIndexOf("$esc[H"))
        $frame | Should -Match ([regex]::Escape("$esc[0;1;38;5;197m▐███▌"))
        $frame | Should -Match ([regex]::Escape("$esc[0;38;5;220m") + '[▗▖]')
        $frame | Should -Match ([regex]::Escape("$esc[0;38;5;208m") + '[▟▜▗]' + '(' + [regex]::Escape("$esc[0;38;5;196m") + '[▙█])?')
        $r.TrueColor = $true
        $r.ItemFinished('Skipped')
        $frame = $t.Writer.ToString()
        $frame.Substring($frame.LastIndexOf("$esc[H")) | Should -Match ([regex]::Escape("$esc[0;1;38;2;229;36;59m▐███▌"))
        $r.Close()

        # It is decoration: a bird that flies over the head of the runner goes through it, and that is no hit.
        $t = New-GameDashboard
        $r = $t.Renderer
        Send-GameText $r 'dead'
        Complete-GameTest $r 'I.1' -Result 'Investigate'
        $through = 0
        foreach ($i in 1..120) {
            $r.AdvanceGame(0.05)
            $bird = @(Get-GameCourse $r 'Bird')[0]
            # Over the runner, with its lowest row where the flame is: four or five rows over the ground.
            if ($bird -and $bird.X -lt 0 -and $bird.X -gt -8 -and $bird.Y -lt 5) { $through++ }
        }
        $through | Should -BeGreaterThan 0
        $r.GameResult.Hits | Should -Be 0
        @(Get-GameCourse $r)[0].Hearts | Should -Be 3
        $r.Close()

        # Under a bridge there is none: the bridge is whole over the head of a runner that runs under it.
        $t = New-GameDashboard -Total 40
        $r = $t.Renderer
        Send-GameText $r 'dead'
        1..10 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        $under = 0
        foreach ($i in 1..160) {
            $r.AdvanceGame(0.05)
            $bridge = @(Get-GameCourse $r 'Platform' | Where-Object { $_.Surface -eq 4 -and $_.From -lt -6 -and $_.To -gt 1 })[0]
            if (-not $bridge -or @(Get-GameCourse $r)[0].Y -ne 0) { continue }
            $under++
            $screen = $r.GetPlainScreen(80, 24)
            $view = Get-GameView $screen
            $screen[$view.Ground - 4].Substring($view.X, 5) | Should -Be '▀▀▀▀▀'
            $screen[$view.Ground - 5].PadRight(80).Substring($view.X, 5) | Should -Not -Match '[▗▖]'
        }
        $under | Should -BeGreaterThan 5
        $r.Close()

        # Without Unicode it is two characters over the head.
        $t = New-GameDashboard -Ascii
        $r = $t.Renderer
        Send-GameText $r 'dead'
        $ascii = @{}
        foreach ($i in 1..18) {
            $r.AdvanceGame(0.04)
            $screen = $r.GetPlainScreen(80, 24)
            $row = @(2..20 | Where-Object { $screen[$_].Contains('[###]') })[0]
            $ascii[$screen[$row - 2].PadRight(80).Substring($screen[$row].IndexOf('[###]'), 5)] = $true
        }
        ($ascii.Keys | Sort-Object) | Should -Be (@(' ,)  ', " ')  ", ' .)  ') | Sort-Object)
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

    It 'Keeps a record of the frames while the game is on screen: how many, the longest time between two, and when that was' {
        $t = New-GameDashboard -Width 124 -Height 40 -Total 60
        $r = $t.Renderer
        $r.GameFrameTiming | Should -BeNullOrEmpty
        $r.Tick()
        # Frames of the dashboard are not in it.
        $r.GameFrameTiming | Should -BeNullOrEmpty
        1..15 | ForEach-Object { Complete-GameTest $r "P.$_" -Result 'Passed' }
        Send-GameText $r 'dead'
        1..5 | ForEach-Object { $r.Tick() }
        $timing = $r.GameFrameTiming
        $timing.Frames | Should -Be 5
        $timing.Characters | Should -BeGreaterThan 2000
        # (On a machine that is busy, one of these may have come late already.)
        $late = $timing.LongGaps
        $late | Should -BeLessOrEqual 4
        # A frame that comes late: the gap is counted, with how far the run was.
        Start-Sleep -Milliseconds 230
        $r.Tick()
        $timing = $r.GameFrameTiming
        $timing.Frames | Should -Be 6
        $timing.LongGaps | Should -Be ($late + 1)
        $timing.LongestGapMs | Should -BeGreaterOrEqual 230
        $timing.WorstAtPercent | Should -Be 25
        # What a tick waited for, at most: for its turn, for the renderer, for the frame, for the console.
        $timing.LongestLateMs, $timing.LongestWaitMs, $timing.LongestBuildMs, $timing.LongestWriteMs | ForEach-Object { $_ | Should -BeGreaterOrEqual 0 }
        ($timing.LongestWaitMs + $timing.LongestBuildMs + $timing.LongestWriteMs) | Should -BeLessOrEqual ($timing.LongestGapMs * 3)
        # The time the game was away is not a time between two frames.
        Send-GameKey $r Escape
        Start-Sleep -Milliseconds 230
        Send-GameText $r 'dead'
        $r.Tick()
        $r.GameFrameTiming.Frames | Should -Be 7
        $r.GameFrameTiming.LongGaps | Should -Be ($late + 1)
        # The next run starts again.
        $r.Stop()
        $r.Start(10)
        $r.GameFrameTiming | Should -BeNullOrEmpty
        $r.Close()
    }

    It 'Is exactly 10,000 for a player that misses nothing in a run in which every test passes, when the game ends with the tests (<Width>x<Height>)' -ForEach @(
        @{ Width = 80; Height = 24; Seed = 31 }, @{ Width = 124; Height = 40; Seed = 32 }, @{ Width = 165; Height = 52; Seed = 33 }
    ) {
        $t = New-GameDashboard -Width $Width -Height $Height -Total 40 -Seed $Seed -Extras
        $r = $t.Renderer
        Send-GameText $r 'dead'
        foreach ($n in 1..40) {
            Complete-GameTest $r "P.$n" -Result 'Passed'
            $null = Invoke-GameBot $r -Seconds 1
        }
        # The tests stop a second after the last one: its coin, and one or two before it, are still on
        # their way. They are not held against the runner.
        $r.GameResult.Coins | Should -BeLessThan 40
        $r.GameResult.Score | Should -BeLessThan 10000
        $r.Stop()
        $result = $r.GameResult
        $result.Coins | Should -BeIn (34..39)
        $result.Hits | Should -Be 0
        $result.Score | Should -Be 10000
        ($r.GetPlainScreen($Width, $Height) -join "`n") | Should -Match 'SCORE 10,000 of 10,000'
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
