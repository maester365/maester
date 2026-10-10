BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    # Environment variables the detection reads; each test sets what it needs and the rest are cleared.
    $script:envNames = 'GITHUB_ACTIONS', 'TF_BUILD', 'CI', 'NO_COLOR', 'TERM', 'MAESTER_OUTPUT_MODE', 'COLORTERM', 'WT_SESSION', 'TERM_PROGRAM', 'TERM_PROGRAM_VERSION', 'ConEmuANSI', 'VTE_VERSION'
    $script:savedEnv = @{}
    foreach ($n in $script:envNames) { $script:savedEnv[$n] = [System.Environment]::GetEnvironmentVariable($n) }

    function Set-TestEnvironment([hashtable] $Values = @{}) {
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
    It 'Writes every count, the total and the report path' {
        $plain = $script:stream.PSObject.Copy(); $plain.Unicode = $false
        $results = [pscustomobject]@{ PassedCount = 3; FailedCount = 2; ErrorCount = 1; InvestigateCount = 0; SkippedCount = 4; NotRunCount = 5; TotalCount = 15; TotalDuration = '00:00:01.5' }
        $text = (InModuleScope Maester -Parameters @{ c = $plain; r = $results } { param($c, $r) Write-MtRunSummary -MaesterResults $r -ReportPath 'out/report.html' -Console $c 6>&1 } | ForEach-Object { "$_" }) -join "`n"
        $text | Should -Match 'Passed: 3, Failed: 2, Errors: 1, Investigate: 0, Skipped: 4, Not run: 5'
        $text | Should -Match '\(15 tests, 1\.5 s\)'
        $text | Should -Match 'Report: out/report\.html'
    }
}

Describe 'Show-MtLogo' {
    It 'Writes one plain line outside Interactive' {
        $text = InModuleScope Maester -Parameters @{ c = $script:stream } { param($c) Show-MtLogo -Console $c 6>&1 } | ForEach-Object { "$_" }
        @($text).Count | Should -Be 1
        $text | Should -Match '^Maester v\d'
    }

    It 'Writes the compact wordmark on a narrow console and the full one on a wide console' {
        $narrow = $script:stream.PSObject.Copy(); $narrow.Mode = 'Interactive'; $narrow.Width = 50; $narrow.Ansi = $true; $narrow.ColorDepth = 'TrueColor'
        $wide = $narrow.PSObject.Copy(); $wide.Width = 120
        $small = (InModuleScope Maester -Parameters @{ c = $narrow } { param($c) Show-MtLogo -Console $c 6>&1 } | ForEach-Object { "$_" }) -join "`n"
        $big = (InModuleScope Maester -Parameters @{ c = $wide } { param($c) Show-MtLogo -Console $c 6>&1 } | ForEach-Object { "$_" }) -join "`n"
        ($small -split "`n").Count | Should -BeLessThan ($big -split "`n").Count
        $big | Should -Match ([regex]::Escape("$([char]27)[38;2;"))
    }
}
