BeforeAll {
    $script:manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
    $script:folder = Join-Path $TestDrive 'suite'
    $null = New-Item -ItemType Directory -Path $script:folder -Force
    @'
Describe 'Sample' -Tag 'Sample' {
    It 'S.1001: passes' -Tag 'S.1001' { $true | Should -BeTrue }
    It 'S.1002: fails' { $false | Should -BeTrue }
    It 'S.1003: preview' -Tag 'Preview' { $true | Should -BeTrue }
    It 'S.1004: long' -Tag 'LongRunning' { $true | Should -BeTrue }
    It 'S.1005: skipped' { Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Nothing to check'; return }
    It 'FAM.1.<_>: family' -ForEach @('a', 'b', 'c') { $true | Should -BeTrue }
    It 'S.1006: inconclusive' { Set-ItResult -Inconclusive -Because 'cannot tell' }
}
'@ | Set-Content (Join-Path $script:folder 'Sample.Tests.ps1')
    # A stale copy of a 2.x built-in wrapper: never run, no row.
    "Describe 'Maester/Entra' { It 'MT.1001: copy of a built-in' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:folder 'Stale.Tests.ps1')

    # Invoke-Maester calls Invoke-Pester, so the runs happen in a child process: all of them in one, for speed.
    $script:scenarios = [ordered]@{
        Default         = ''
        TestId          = "-TestId 'S.1001','S.1003'"
        FamilyInstance  = "-TestId 'FAM.1.b'"
        Unknown         = "-TestId 'S.1001','NOPE.1'"
        UnknownError    = "-TestId 'NOPE.1' -Config @{ Selection = @{ OnUnknownId = 'Error' } }"
        ExcludeTestId   = "-ExcludeTestId 'S.1002'"
        Disabled        = "-Config @{ TestSettings = @(@{ Id = 'S.1002'; Enabled = `$false; Reason = 'Accepted' }) }"
        DisabledInstance = "-Config @{ TestSettings = @(@{ Id = 'FAM.1.a'; Enabled = `$false; Reason = 'Not ours' }) }"
        AllowList       = "-Config @{ Selection = @{ DefaultAction = 'Skip' }; TestSettings = @(@{ Id = 'S.1001'; Enabled = `$true }) }"
        Metadata        = "-Config @{ Metadata = @{ RunId = 'run-42' } }"
        DryRunExclude   = "-DryRun -ExcludeTestId 'S.1002'"
        DryRun          = '-DryRun'
        HashtableConfig = "-PesterConfiguration @{ Output = @{ Verbosity = 'None' }; Run = @{ ExcludePath = @('nothing.Tests.ps1') } }"
        # These run the built-in tests too (no -SkipBuiltIn).
        WithBuiltIn     = 'BUILTIN -TestId S.1001, MT.1001, MT.1002'
        MissingPath     = 'BUILTIN MISSINGPATH -TestId MT.1001'
        # Pester is not installed: Import-MtPester is replaced in the module for the rest of the process, so this runs last.
        NoPester        = 'NOPESTER'
    }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("`$ErrorActionPreference = 'Continue'")
    $lines.Add("Import-Module '$script:manifest' -WarningAction SilentlyContinue")
    foreach ($name in $script:scenarios.Keys) {
        $out = Join-Path $TestDrive "$name.json"
        $arguments = $script:scenarios[$name]
        $skip = if ($arguments -like 'BUILTIN*') { '' } else { '-SkipBuiltIn' }
        $path = if ($arguments -like '*MISSINGPATH*') { Join-Path $TestDrive 'does-not-exist' } else { $script:folder }
        $arguments = $arguments -replace '^BUILTIN ', '' -replace '^MISSINGPATH ', ''
        if ($arguments -eq 'NOPESTER') {
            $arguments = ''
            $lines.Add("& (Get-Module Maester) { function script:Import-MtPester { `$false } }")
        }
        $lines.Add("try { `$null = Invoke-Maester -Path '$path' $skip -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$out' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue $arguments } catch { }")
    }
    $null = pwsh -NoProfile -NonInteractive -Command ($lines -join [Environment]::NewLine) 2>&1

    function Invoke-MaesterRun {
        param([string] $Scenario)
        $out = Join-Path $TestDrive "$Scenario.json"
        if (Test-Path $out) { Get-Content $out -Raw | ConvertFrom-Json } else { $null }
    }

    function Get-Row {
        param($Result, [string] $Id)
        $Result.Tests | Where-Object Id -EQ $Id
    }
}

Describe 'Invoke-Maester selection (Pester provider)' {
    Context 'Default run' {
        BeforeAll { $script:r = Invoke-MaesterRun 'Default' }

        It 'Writes result schema 2.1 with the additive fields' {
            $r.SchemaVersion | Should -Be '2.1'
            $r.CatalogVersion | Should -BeOfType [string]
            $r.CatalogVersion | Should -Match '^\d+\.\d+'
            $r.Selection.BuiltIn | Should -Be 'None'
            @($r.Selection.UnknownIds).Count | Should -Be 0
            (Get-Row $r 'S.1001').Format | Should -Be 'Pester'
        }

        It 'Keeps the 2.x results' {
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
            (Get-Row $r 'S.1002').Result | Should -Be 'Failed'
            (Get-Row $r 'S.1005').Result | Should -Be 'Skipped'
        }

        It 'Reports a Pester Inconclusive result as Skipped' {
            $row = Get-Row $r 'S.1006'
            $row.Result | Should -Be 'Skipped'
            $row.ReasonCode | Should -Be 'TestSkipped'
            @($r.Tests | Where-Object Result -EQ 'Inconclusive') | Should -HaveCount 0
        }

        It 'Gives NotRun rows a reason code' {
            (Get-Row $r 'S.1003').ReasonCode | Should -Be 'Preview'
            (Get-Row $r 'S.1004').ReasonCode | Should -Be 'LongRunning'
        }

        It 'Gives a skipped row TestSkipped and keeps the legacy code in ResultDetail' {
            $row = Get-Row $r 'S.1005'
            $row.ReasonCode | Should -Be 'TestSkipped'
            $row.ResultDetail.TestSkipped | Should -Be 'Custom'
        }

        It 'Marks family instances with their parent ID' {
            $row = Get-Row $r 'FAM.1.a'
            $row.ParentId | Should -Be 'FAM.1'
            $row.InstanceId | Should -Be 'FAM.1.a'
        }
    }

    Context 'Pester configuration and availability' {
        It 'Accepts a hashtable for -PesterConfiguration' {
            $r = Invoke-MaesterRun 'HashtableConfig'
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
            (Get-Row $r 'S.1002').Result | Should -Be 'Failed'
        }

        It 'Reports each Pester-format test as PesterNotAvailable when Pester is missing' {
            $r = Invoke-MaesterRun 'NoPester'
            $r | Should -Not -BeNullOrEmpty
            $row = Get-Row $r 'S.1001'
            $row.Result | Should -Be 'Error'
            $row.ReasonCode | Should -Be 'PesterNotAvailable'
            $row.Format | Should -Be 'Pester'
            (Get-Row $r 'FAM.1').ReasonCode | Should -Be 'PesterNotAvailable'
            # Tests the tag filter leaves out (Preview, LongRunning by default) get no row.
            Get-Row $r 'S.1003' | Should -BeNullOrEmpty
            Get-Row $r 'S.1004' | Should -BeNullOrEmpty
        }
    }

    Context '-TestId' {
        It 'Runs only the named tests, including a preview test named exactly' {
            $r = Invoke-MaesterRun 'TestId'
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
            (Get-Row $r 'S.1003').Result | Should -Be 'Passed'
            (Get-Row $r 'S.1002').ReasonCode | Should -Be 'NotSelected'
            (Get-Row $r 'S.1004').ReasonCode | Should -Be 'NotSelected'
        }

        It 'Reports the instances of a family that were not named as DeselectedAtRuntime' {
            $r = Invoke-MaesterRun 'FamilyInstance'
            (Get-Row $r 'FAM.1.b').Result | Should -Be 'Passed'
            $other = Get-Row $r 'FAM.1.a'
            $other.Result | Should -Be 'NotRun'
            $other.ReasonCode | Should -Be 'DeselectedAtRuntime'
        }

        It 'Disables one instance of a family and still runs the others' {
            $r = Invoke-MaesterRun 'DisabledInstance'
            $disabled = Get-Row $r 'FAM.1.a'
            $disabled.Result | Should -Be 'NotRun'
            $disabled.ReasonCode | Should -Be 'DisabledByConfig'
            $disabled.ReasonDetail | Should -Be 'Not ours'
            (Get-Row $r 'FAM.1.b').Result | Should -Be 'Passed'
            (Get-Row $r 'FAM.1.c').Result | Should -Be 'Passed'
        }

        It 'Lists unknown IDs and stops when OnUnknownId is Error' {
            $warn = Invoke-MaesterRun 'Unknown'
            $warn.Selection.UnknownIds | Should -Be @('NOPE.1')
            $stopped = Invoke-MaesterRun 'UnknownError'
            $stopped | Should -BeNullOrEmpty
        }
    }

    Context '-ExcludeTestId and config' {
        It 'Excludes by ID' {
            $r = Invoke-MaesterRun 'ExcludeTestId'
            (Get-Row $r 'S.1002').ReasonCode | Should -Be 'ExcludedById'
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
        }

        It 'Disables a test through TestSettings and keeps it as a NotRun row' {
            $r = Invoke-MaesterRun 'Disabled'
            $row = Get-Row $r 'S.1002'
            $row.Result | Should -Be 'NotRun'
            $row.ReasonCode | Should -Be 'DisabledByConfig'
            $row.ReasonDetail | Should -Be 'Accepted'
        }

        It 'Runs only enabled tests in allow-list mode' {
            $r = Invoke-MaesterRun 'AllowList'
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
            (Get-Row $r 'S.1002').ReasonCode | Should -Be 'NotListed'
        }

        It 'Echoes the config Metadata as RunMetadata' {
            $r = Invoke-MaesterRun 'Metadata'
            $r.RunMetadata.RunId | Should -Be 'run-42'
            $r.MaesterConfig.ConfigSource | Should -Be '-Config'
        }
    }

    Context '-DryRun' {
        It 'Runs nothing and reports what would run as DryRun' {
            $r = Invoke-MaesterRun 'DryRunExclude'
            @($r.Tests | Where-Object { $_.Result -ne 'NotRun' }).Count | Should -Be 0
            (Get-Row $r 'S.1001').ReasonCode | Should -Be 'DryRun'
            (Get-Row $r 'S.1002').ReasonCode | Should -Be 'ExcludedById'
            (Get-Row $r 'S.1003').ReasonCode | Should -Be 'Preview'
        }

        It 'Reports a family as one row on its parent ID' {
            $r = Invoke-MaesterRun 'DryRun'
            $family = @($r.Tests | Where-Object ParentId -EQ 'FAM.1')
            $family.Id | Select-Object -Unique | Should -Be 'FAM.1'
        }
    }

    Context 'Built-in tests and custom tests (M2)' {
        It 'Runs built-in tests from the module next to the custom tests' {
            $r = Invoke-MaesterRun 'WithBuiltIn'
            (Get-Row $r 'S.1001').Result | Should -Be 'Passed'
            $builtIn = Get-Row $r 'MT.1002'
            $builtIn | Should -Not -BeNullOrEmpty
            $builtIn.Source | Should -Be 'Maester'
            $builtIn.Suite | Should -Be 'Maester'
            (Get-Row $r 'S.1001').Source | Should -Be 'Custom'
            $r.Selection.BuiltIn | Should -Be 'All'
        }

        It 'Does not run or report a stale copy of a built-in test' {
            $r = Invoke-MaesterRun 'WithBuiltIn'
            @($r.Tests | Where-Object Id -EQ 'MT.1001') | Should -HaveCount 1
            (Get-Row $r 'MT.1001').ScriptBlockFile | Should -Not -BeLike '*Stale.Tests.ps1'
            $r.Selection.Superseded.Id | Should -Contain 'MT.1001'
        }

        It 'Supersedes stale copies with -SkipBuiltIn too' {
            $r = Invoke-MaesterRun 'Default'
            Get-Row $r 'MT.1001' | Should -BeNullOrEmpty
            $r.Selection.BuiltIn | Should -Be 'None'
            @($r.Tests | Where-Object Source -NE 'Custom') | Should -HaveCount 0
        }

        It 'Still runs the built-in tests when -Path does not exist' {
            $r = Invoke-MaesterRun 'MissingPath'
            $r | Should -Not -BeNullOrEmpty
            (Get-Row $r 'MT.1001') | Should -Not -BeNullOrEmpty
        }
    }
}
