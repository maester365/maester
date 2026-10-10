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
        ($screen | Where-Object { $_ -match '^ Azure' }) | Should -Match '3 skipped'
        ($screen | Where-Object { $_ -match '^ Running' }) | Should -Match '2 tests'
        @($screen | Where-Object { $_ -match ' (E\.1|E\.2) ' }).Count | Should -Be 2
        # The test that finished is no longer running: it is listed under the running ones, with its result.
        $running = [array]::IndexOf($screen, ($screen | Where-Object { $_ -match '^ Running' }))
        $screen[$running + 3] | Should -Match '^ ✗ T\.1 +Second +[\d.]+ s$'
        $t.Renderer.Failed | Should -Be 1
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
        $screen[0] | Should -Be ' Maester v3'
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
        $t = New-TestPanelDashboard -Panels 'Tips', 'Tenant'
        $t.Renderer.SetTips(@('A tip'))
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('Contoso'))
        $t.Renderer.Start(2)
        $t.Renderer.ItemFinished('Failed')
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen.IndexOf('Tip') | Should -BeLessThan $screen.IndexOf('Tenant')
        $screen | Should -Not -Match 'Failed so far'
        $screen | Should -Not -Match '■'
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

    It 'Fills a console that is wider and taller than the standard layout' {
        $t = New-TestPanelDashboard -Width 200 -Panels 'Failed', 'Pace', 'Results'
        $t.Renderer.Start(700)
        1..40 | ForEach-Object { $t.Renderer.ItemStarting("W.$_", "Test $_", $null); $t.Renderer.ItemFinished("W.$_", 'Failed', 'High') }
        $screen = $t.Renderer.GetPlainScreen(200, 50)
        # The right column ends at the edge of the window, and is wider than on a 160-column console.
        $boxes = @($screen | Where-Object { $_ -match '╮$' })
        $boxes.Count | Should -Be 2
        $boxes | ForEach-Object { $_.Length | Should -Be 199 }
        ($boxes[0] -replace '^.*(?=╭)').Length | Should -BeGreaterThan 58
        # One square per test: 700 squares over more rows than the standard six would hold.
        (($screen -join '') -replace '[^■□]').Length | Should -Be 700
        ($screen -join "`n") | Should -Not -Match 'each square is'
        # The Pace panel fills the rows that are free with more of the slowest tests (twenty at most).
        @($screen | Where-Object { $_ -match '│ W\.\d+ ' }).Count | Should -Be 20
        $t.Renderer.Close()

        # It gives the rows back when another panel needs them: every panel is still there, and the column is full.
        $t = New-TestPanelDashboard -Width 200 -Panels 'Tenant', 'Failed', 'Pace', 'Tips'
        $t.Renderer.SetPanelText('Tenant', 'Tenant', @('One', 'Two', 'Three'))
        $t.Renderer.SetTips(@('A tip'))
        $t.Renderer.Start(700)
        1..40 | ForEach-Object { $t.Renderer.ItemStarting("W.$_", "Test $_", $null); $t.Renderer.ItemFinished("W.$_", 'Failed', 'High') }
        $short = $t.Renderer.GetPlainScreen(200, 30)
        @($short | Where-Object { $_ -match '╭─ (Tenant|Failed so far|Pace|Tip) ' }).Count | Should -Be 4
        $slow = @($short | Where-Object { $_ -match '│ W\.\d+ ' }).Count
        $slow | Should -BeGreaterThan 3
        $slow | Should -BeLessThan 20
        @($short | Where-Object { $_ -match '[│╮╯]$' }).Count | Should -Be 29
        $t.Renderer.Close()
    }

    It 'Shows the address of a tip under it, as a hyperlink' {
        $t = New-TestPanelDashboard -Panels 'Tips'
        $t.Renderer.SetTips(@('A tip with a page'), @('https://maester.dev/docs/monitoring'))
        $t.Renderer.Start(1)
        $screen = $t.Renderer.GetPlainScreen(160, 44) -join "`n"
        $screen | Should -Match '│ A tip with a page +│'
        $screen | Should -Match '│ maester\.dev/docs/monitoring +│'
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev/docs/monitoring$esc\maester.dev/docs/monitoring$esc]8;;$esc\"))
        $t.Renderer.Close()

        # A tip without an address has no extra line.
        $plain = New-TestPanelDashboard -Panels 'Tips'
        $plain.Renderer.SetTips(@('A tip', 'Another'), @($null))
        $plain.Renderer.Start(1)
        ($plain.Renderer.GetPlainScreen(160, 44) -join "`n") | Should -Match '│ A tip +│\n[^\n]*╰'
        $plain.Renderer.Close()
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

    It 'Lays out the Tenant panel: name and domain on one line, the counts in right-aligned columns' {
        $t = New-TestPanelDashboard -Panels 'Tenant'
        $t.Renderer.SetTenant('Contoso', 'contoso.com', 'merill@contoso.com · Delegated', @('Users', 'Guests', 'Devices', 'Groups', 'Apps', 'Agents'), @('1.2K', '87', '432', '310', '95', '4'))
        $t.Renderer.Start(1)
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        $box = @($screen | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $box[1] | Should -Match '^│ Contoso +contoso\.com │$'
        $box[2] | Should -Match '^│ merill@contoso\.com · Delegated +│$'
        # Six columns of nine: each value ends where its label ends.
        $box[3] | Should -Be '│      1.2K       87      432      310       95        4 │'
        $box[4] | Should -Be '│     Users   Guests  Devices   Groups     Apps   Agents │'
        $t.Renderer.Close()

        # A narrower panel has two rows of three, and a long name is cut to keep the domain.
        $narrow = New-TestPanelDashboard -Width 142 -Panels 'Tenant'
        $narrow.Renderer.SetTenant('A tenant with a very long display name', 'contoso.onmicrosoft.com', $null, @('Users', 'Guests', 'Devices', 'Groups', 'Apps', 'Agents'), @('1.2K', '87', '432', '310', '95', '4'))
        $narrow.Renderer.Start(1)
        $small = @($narrow.Renderer.GetPlainScreen(142, 44) | Where-Object { $_ -match '[│╭╰]' } | ForEach-Object { $_ -replace '^.*?(?=[│╭╰])' })
        $small[1] | Should -Match '^│ A tenant…? ?\S*… +contoso\.onmicrosoft\.com │$|^│ A tenant\S*… contoso\.onmicrosoft\.com │$'
        $small[2] | Should -Match '^│ +1\.2K +87 +432 │$'
        $small[3] | Should -Match '^│ +Users +Guests +Devices │$'
        $small[5] | Should -Match '^│ +Groups +Apps +Agents │$'
        $narrow.Renderer.Close()
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

    It 'Writes the tagline of the banner, and mentions a newer version in it as a link' {
        $t = New-TestPanelDashboard -Panels 'Tips'
        $t.Renderer.SetHeader(@('top', 'FLAME  old tagline', 'bottom'), 30, 'Maester v3.0.0')
        $t.Renderer.SetHeaderTagline(1, 'FLAME  ', 44, 'v3.0.0', 'maester.dev', 'https://maester.dev')
        $t.Renderer.Start(1)
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        $screen[1] | Should -Match ('^FLAME  ' + (' ' * 24) + 'v3\.0\.0 · maester\.dev\b')
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc]8;;https://maester.dev$esc\maester.dev$esc]8;;$esc\"))

        $t.Renderer.SetHeaderUpdate('v3.1.0 available', 'https://www.powershellgallery.com/packages/Maester/3.1.0')
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        $screen[1] | Should -Match '^FLAME     v3\.0\.0 · ↑ v3\.1\.0 available · maester\.dev\b'
        $t.Writer.ToString() | Should -Match ([regex]::Escape("$esc[1;38;5;215m$esc]8;;https://www.powershellgallery.com/packages/Maester/3.1.0$esc\↑ v3.1.0 available$esc]8;;$esc\"))
        # There is no Version panel.
        ($screen -join "`n") | Should -Not -Match '╭─ Version'
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
        $screen[$running + 2] | Should -Match '^ ✓ H\.40 +Test 40 +[\d.]+ s$'
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
        $t.Renderer.Start(1)
        $screen = $t.Renderer.GetPlainScreen(160, 30)
        $screen.Count | Should -Be 30
        $screen[29] | Should -Be (' maester.dev  Contributors │ Our Manifesto │ ♥ Sponsor ').PadRight(159)
        $screen[1] | Should -Match '^FLAME +v3\.0\.0$'
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

    It 'Shows the pace and the slowest tests' {
        $t = New-TestPanelDashboard
        $t.Renderer.Start(3)
        $t.Renderer.ItemStarting('S.1', 'Slow one')
        Start-Sleep -Milliseconds 60
        $t.Renderer.ItemFinished('S.1', 'Passed', 'Low')
        $t.Renderer.ItemStarting('S.2', 'Quick one')
        $t.Renderer.ItemFinished('S.2', 'Passed', 'Low')
        $screen = $t.Renderer.GetPlainScreen(160, 44)
        ($screen -join "`n") | Should -Match '╭─ Pace ─+ [\d.]+ tests/s ─╮'
        $slow = @($screen | Where-Object { $_ -match '│ S\.[12] ' })
        $slow[0] | Should -Match 'S\.1 .*Slow one'
        $t.Renderer.Close()
    }

    It 'Wraps a tip to the width of the column' {
        $t = New-TestPanelDashboard -Width 141
        $t.Renderer.SetTips(@('one two three four five six seven eight nine ten eleven twelve thirteen fourteen'))
        $screen = $t.Renderer.GetPlainScreen(141, 44)
        ($screen | Where-Object { $_ -match '╭─ Tip ─+╮$' }) | Should -Not -BeNullOrEmpty
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
        & $chart | Should -Be '■■■··□□□□□'
        $t.Renderer.ItemFinished('R.1', 'Passed')
        & $chart | Should -Be '■■■■·□□□□□'
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
