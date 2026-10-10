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
        ($screen -join "`n") | Should -Not -Match 'T\.1'
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
