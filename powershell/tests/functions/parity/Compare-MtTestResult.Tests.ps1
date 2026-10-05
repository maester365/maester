BeforeDiscovery {
    $script:RepoRootForDiscovery = (Resolve-Path "$PSScriptRoot/../../../..").Path
    $script:HasReportSample = Test-Path -LiteralPath (Join-Path $script:RepoRootForDiscovery 'report/src/lib/testResults.ts')
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
    $script:Differ = Join-Path $script:RepoRoot 'build/parity/Compare-MtTestResult.ps1'
    $script:AllowList = Join-Path $script:RepoRoot 'build/parity/parity-allowlist.psd1'
    $script:FixtureRoot = Join-Path $script:RepoRoot 'powershell/tests/fixtures/parity'
    $script:Old2x = Join-Path $script:FixtureRoot 'result-2x.json'
    $script:New3x = Join-Path $script:FixtureRoot 'result-3x-allowlisted.json'

    function Get-Fixture {
        param([string] $Path = $script:Old2x)
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100
    }

    function Get-Row {
        param($Result, [string] $Id, [int] $Occurrence = 1)
        @($Result.Tests | Where-Object { $_.Id -eq $Id })[$Occurrence - 1]
    }

    function Invoke-Differ {
        param($Old, $New, [hashtable] $Extra = @{})
        & $script:Differ -OldResult $Old -NewResult $New @Extra
    }

    function Add-RowProperty {
        param($Row, [hashtable] $Properties)
        foreach ($name in $Properties.Keys) {
            $Row | Add-Member -NotePropertyName $name -NotePropertyValue $Properties[$name] -Force
        }
    }
}

Describe 'build/parity/Compare-MtTestResult.ps1' {

    Context 'identical inputs (M0 gate: 2.x against itself)' {
        It 'reports no difference for the synthetic 2.x fixture against itself' {
            $differences = & $script:Differ -OldPath $script:Old2x -NewPath $script:Old2x
            @($differences).Count | Should -Be 0
        }

        It 'passes -FailOnDifference with exit code 0' {
            $null = & $script:Differ -OldPath $script:Old2x -NewPath $script:Old2x -FailOnDifference
            $LASTEXITCODE | Should -Be 0
        }

        It 'reports no difference for the report app sample result against itself' -Skip:(-not $script:HasReportSample) {
            # report/src/lib/testResults.ts embeds a real 2.x result (317 rows) as a JS object literal.
            $source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'report/src/lib/testResults.ts') -Raw
            $start = $source.IndexOf('{')
            $end = $source.LastIndexOf('}')
            $samplePath = Join-Path $TestDrive 'report-sample.json'
            Set-Content -LiteralPath $samplePath -Value $source.Substring($start, $end - $start + 1) -Encoding utf8NoBOM

            $summary = & $script:Differ -OldPath $samplePath -NewPath $samplePath -Summary
            $summary.OldRowCount | Should -BeGreaterThan 100
            $summary.MatchedRows | Should -Be $summary.OldRowCount
            $summary.DifferenceCount | Should -Be 0
            $summary.Passed | Should -BeTrue
        }
    }

    Context 'row field differences' {
        It 'detects a difference in <Field>' -ForEach @(
            @{ Field = 'Result'; Id = 'MT.1001'; Path = 'Result'; Value = 'Investigate' }
            @{ Field = 'Severity'; Id = 'MT.1001'; Path = 'Severity'; Value = 'Low' }
            @{ Field = 'Title'; Id = 'MT.1001'; Path = 'Title'; Value = 'Changed title' }
            @{ Field = 'Name'; Id = 'MT.1001'; Path = 'Name'; Value = 'MT.1001: Changed title' }
            @{ Field = 'Block'; Id = 'MT.1001'; Path = 'Block'; Value = 'Entra' }
            @{ Field = 'HelpUrl'; Id = 'MT.1001'; Path = 'HelpUrl'; Value = 'https://example.test/MT.1001' }
            @{ Field = 'TestSkipped'; Id = 'CISA.MS.EXO.1.1'; Path = 'ResultDetail.TestSkipped'; Value = 'NotConnectedGraph' }
            @{ Field = 'SkippedReason'; Id = 'CISA.MS.EXO.1.1'; Path = 'ResultDetail.SkippedReason'; Value = 'Different reason' }
        ) {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new $Id
            if ($Path -like 'ResultDetail.*') {
                $row.ResultDetail.($Path.Split('.')[1]) = $Value
            } else {
                $row.$Path = $Value
            }

            $differences = @(Invoke-Differ -Old $old -New $new | Where-Object Id -EQ $Id)
            $differences.Count | Should -Be 1
            $differences[0].Field | Should -Be $Field
            $differences[0].New | Should -Be $Value
            $differences[0].AllowListed | Should -BeFalse
        }

        It 'compares tags as a set: order and case do not matter' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new 'MT.1001'
            $row.Tag = @('mt.1001', 'CA', 'MAESTER')
            @(Invoke-Differ -Old $old -New $new).Count | Should -Be 0
        }

        It 'reports one difference per added and removed tag' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'MT.1001').Tag = @('Maester', 'MT.1001', 'Added tag')

            $differences = @(Invoke-Differ -Old $old -New $new)
            $differences.Count | Should -Be 2
            ($differences | Where-Object { $_.Old -eq 'CA' -and $_.New -eq '' }) | Should -Not -BeNullOrEmpty
            ($differences | Where-Object { $_.Old -eq '' -and $_.New -eq 'Added tag' }) | Should -Not -BeNullOrEmpty
        }

        It 'treats a null and an empty Severity as equal' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'CT.0002').Severity = $null
            @(Invoke-Differ -Old $old -New $new).Count | Should -Be 0
        }

        It 'joins rows by Name when Id is empty' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = @($new.Tests | Where-Object { $_.Id -eq '' })[0]
            $row.Result = 'Failed'
            $differences = @(Invoke-Differ -Old $old -New $new | Where-Object Field -EQ 'Result')
            $differences.Count | Should -Be 1
            $differences[0].Id | Should -Be 'Custom check without an ID colon'
        }

        It 'restricts the row comparison with -Field' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'MT.1001').Title = 'Changed title'
            @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' }).Count | Should -Be 0
        }
    }

    Context 'run-level differences' {
        It 'detects a top-level Result and count difference' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'MT.1100').Result = 'Passed'
            $new.FailedCount = $new.FailedCount - 1
            $new.PassedCount = $new.PassedCount + 1

            $differences = @(Invoke-Differ -Old $old -New $new)
            ($differences | Where-Object { $_.Id -eq '(run)' }).Field | Sort-Object | Should -Be @('FailedCount', 'PassedCount')
            $differences | ForEach-Object { $_.AllowListed | Should -BeFalse }
        }

        It 'detects a top-level Result change' {
            $old = Get-Fixture
            $new = Get-Fixture
            $new.Result = 'Passed'
            $difference = @(Invoke-Differ -Old $old -New $new | Where-Object { $_.Id -eq '(run)' -and $_.Field -eq 'Result' })
            $difference.Count | Should -Be 1
            $difference[0].AllowListed | Should -BeFalse
        }
    }

    Context 'presence' {
        It 'reports a row missing from the new file' {
            $old = Get-Fixture
            $new = Get-Fixture
            $new.Tests = @($new.Tests | Where-Object Id -NE 'MT.1001')
            $difference = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Field -EQ 'Presence')
            $difference.Count | Should -Be 1
            $difference[0].Id | Should -Be 'MT.1001'
            $difference[0].Old | Should -Be 'Passed'
            $difference[0].New | Should -Be ''
            $difference[0].AllowListed | Should -BeFalse
        }

        It 'reports an extra row in the new file' {
            $old = Get-Fixture
            $new = Get-Fixture
            $extra = (Get-Row $new 'MT.1001' | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
            $extra.Id = 'MT.9999'
            $new.Tests = @($new.Tests) + $extra
            $summary = Invoke-Differ -Old $old -New $new -Extra @{ Summary = $true }
            $summary.ExtraRows | Should -Be 1
            $summary.MissingRows | Should -Be 0
            $difference = @(Invoke-Differ -Old $old -New $new | Where-Object Field -EQ 'Presence')
            $difference[0].Id | Should -Be 'MT.9999'
            $difference[0].Old | Should -Be ''
            $difference[0].New | Should -Be 'Passed'
        }
    }

    Context 'duplicate IDs' {
        It 'pairs duplicate rows in order and lists the key in the summary' {
            $summary = & $script:Differ -OldPath $script:Old2x -NewPath $script:Old2x -Summary
            $summary.DuplicateKeys.Count | Should -Be 1
            $summary.DuplicateKeys[0].Key | Should -Be 'CT.0001'
            $summary.DuplicateKeys[0].OldCount | Should -Be 2
            $summary.DifferenceCount | Should -Be 0
        }

        It 'attributes a change to the second occurrence only' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'CT.0001' -Occurrence 2).Result = 'Passed'
            $differences = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Id -EQ 'CT.0001')
            $differences.Count | Should -Be 1
            $differences[0].Occurrence | Should -Be 2
            $differences[0].Old | Should -Be 'Failed'
        }

        It 'reports a duplicate that disappears as a missing row' {
            $old = Get-Fixture
            $new = Get-Fixture
            $second = Get-Row $new 'CT.0001' -Occurrence 2
            $new.Tests = @($new.Tests | Where-Object { -not [object]::ReferenceEquals($_, $second) })
            $differences = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Field -EQ 'Presence')
            $differences.Count | Should -Be 1
            $differences[0].Occurrence | Should -Be 2
        }
    }

    Context 'allow-list' {
        It 'loads the allow-list data file' {
            $data = Import-PowerShellDataFile -LiteralPath $script:AllowList
            $data.Rules.Count | Should -BeGreaterThan 5
            $data.Rules | ForEach-Object { $_.Name | Should -Not -BeNullOrEmpty; $_.Field | Should -Not -BeNullOrEmpty }
            ($data.Rules.Name | Select-Object -Unique).Count | Should -Be $data.Rules.Count
        }

        It 'flags every intended 2.x to 3.0 difference in the fixture pair as allow-listed' {
            $differences = @(& $script:Differ -OldPath $script:Old2x -NewPath $script:New3x)
            $differences.Count | Should -BeGreaterThan 0
            $differences | Where-Object { -not $_.AllowListed } | Should -BeNullOrEmpty
            $rules = $differences.AllowListRule | Select-Object -Unique
            foreach ($expected in 'NativeUncaughtExceptionIsError', 'NativeErrorDropsTestSkippedMarker', 'ContextNestedDescribeTags',
                'HelpUrlFromTemplate', 'LoadFailedRow', 'DerivedFromAllowListedRows') {
                $rules | Should -Contain $expected
            }
            $null = & $script:Differ -OldPath $script:Old2x -NewPath $script:New3x -FailOnDifference
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not allow-list Failed -> Error for a Pester row' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new 'MT.1100'
            $row.Result = 'Error'
            Add-RowProperty $row @{ Format = 'Pester'; ReasonCode = 'TestError' }
            $difference = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Id -EQ 'MT.1100')
            $difference[0].AllowListed | Should -BeFalse
        }

        It 'never allow-lists Failed -> Skipped, even with an allow rule that matches' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new 'MT.1100'
            $row.Result = 'Skipped'
            Add-RowProperty $row @{ Format = 'Native'; ReasonCode = 'ServiceNotConnected' }

            $customAllowList = Join-Path $TestDrive 'permissive.psd1'
            $source = Get-Content -LiteralPath $script:AllowList -Raw
            # Add a rule that would allow any Result change, to prove deny rules win.
            $source = $source -replace 'Rules = @\(', "Rules = @(`n        @{ Name = 'AnyResult'; Field = 'Result' }"
            Set-Content -LiteralPath $customAllowList -Value $source

            $difference = @(Invoke-Differ -Old $old -New $new -Extra @{ AllowListPath = $customAllowList } | Where-Object { $_.Id -eq 'MT.1100' -and $_.Field -eq 'Result' })
            $difference.Count | Should -Be 1
            $difference[0].AllowListed | Should -BeFalse
            $difference[0].DenyRule | Should -Be 'FailedToSkippedNeverAllowListed'
        }

        It 'allow-lists Error -> Skipped with ReasonCode ServiceNotConnected' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new 'ORCA.100'
            $row.Result = 'Skipped'
            Add-RowProperty $row @{ Format = 'Native'; ReasonCode = 'ServiceNotConnected' }
            $row.ResultDetail.TestSkipped = 'NotConnectedExchange'
            $row.ResultDetail.SkippedReason = 'Not connected to Exchange Online.'
            $new.ErrorCount = $new.ErrorCount - 1
            $new.SkippedCount = $new.SkippedCount + 1

            $differences = @(Invoke-Differ -Old $old -New $new)
            $differences | Where-Object { -not $_.AllowListed } | Should -BeNullOrEmpty
            ($differences | Where-Object Field -EQ 'Result').AllowListRule | Should -Be 'ServiceNotConnectedFromError'
        }

        It 'only allow-lists Passed -> Skipped/NotApplicable for listed IDs' {
            $old = Get-Fixture
            $new = Get-Fixture
            $row = Get-Row $new 'MT.1187'
            $row.Result = 'Skipped'
            Add-RowProperty $row @{ Format = 'Native'; ReasonCode = 'NotApplicable' }

            $unlisted = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Id -EQ 'MT.1187')
            $unlisted[0].AllowListed | Should -BeFalse

            $customAllowList = Join-Path $TestDrive 'listed.psd1'
            (Get-Content -LiteralPath $script:AllowList -Raw) -replace 'IdList\s*=\s*@\(\)', "IdList = @('MT.1187')" |
                Set-Content -LiteralPath $customAllowList
            $listed = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result'; AllowListPath = $customAllowList } | Where-Object Id -EQ 'MT.1187')
            $listed[0].AllowListed | Should -BeTrue
            $listed[0].AllowListRule | Should -Be 'NullReturnNotApplicable'
        }

        It 'allow-lists new rows when the run used -Tag All' {
            $old = Get-Fixture
            $new = Get-Fixture
            $extra = (Get-Row $new 'MT.1001' | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
            $extra.Id = 'MT.1065'
            $new.Tests = @($new.Tests) + $extra
            $new.InvokeCommand = 'Invoke-Maester -Tag All'
            $difference = @(Invoke-Differ -Old $old -New $new -Extra @{ Field = 'Result' } | Where-Object Field -EQ 'Presence')
            $difference[0].AllowListRule | Should -Be 'TagAllOrFullSelectsTests'
        }

        It 'reports everything as not allow-listed with -NoAllowList' {
            $differences = @(& $script:Differ -OldPath $script:Old2x -NewPath $script:New3x -NoAllowList)
            $differences | Where-Object AllowListed | Should -BeNullOrEmpty
        }

        It 'does not derive run-level allow-listing when a row difference is not allow-listed' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'MT.1100').Result = 'Passed'
            $new.FailedCount = $new.FailedCount - 1
            $new.PassedCount = $new.PassedCount + 1
            $differences = @(Invoke-Differ -Old $old -New $new | Where-Object Id -EQ '(run)')
            $differences | Where-Object AllowListed | Should -BeNullOrEmpty
        }
    }

    Context 'output modes' {
        It 'exits 1 with -FailOnDifference when a difference is not allow-listed' {
            $old = Get-Fixture
            (Get-Row $old 'MT.1001').Result = 'Failed'
            $oldPath = Join-Path $TestDrive 'changed.json'
            $old | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $oldPath
            $output = & pwsh -NoProfile -NonInteractive -File $script:Differ -OldPath $oldPath -NewPath $script:Old2x -FailOnDifference -Summary 2>&1
            $LASTEXITCODE | Should -Be 1
            ($output | Out-String) | Should -Match 'Parity check failed'
        }

        It 'writes a Markdown report' {
            $old = Get-Fixture
            $new = Get-Fixture
            (Get-Row $new 'MT.1100').Title = 'Title with | pipe'
            $markdown = Invoke-Differ -Old $old -New $new -Extra @{ AsMarkdown = $true }
            $markdown | Should -BeOfType [string]
            $markdown | Should -Match '# Maester parity report'
            $markdown | Should -Match 'FAIL: 1 difference'
            $markdown | Should -Match 'Title with \\\| pipe'
            $markdown | Should -Match '## Duplicate keys'
        }

        It 'writes a passing Markdown report with the allow-listed rule table' {
            $markdown = & $script:Differ -OldPath $script:Old2x -NewPath $script:New3x -AsMarkdown
            $markdown | Should -Match 'PASS'
            $markdown | Should -Match '\| LoadFailedRow \| 1 \|'
        }

        It 'rejects a file that is not a Maester result' {
            $path = Join-Path $TestDrive 'not-a-result.json'
            '{ "Foo": 1 }' | Set-Content -LiteralPath $path
            { & $script:Differ -OldPath $path -NewPath $script:Old2x } | Should -Throw '*no Tests array*'
        }
    }
}
