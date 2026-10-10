BeforeDiscovery {
    $script:GoldenRoot = (Resolve-Path "$PSScriptRoot/../../fixtures/golden").Path
    $script:GoldenFiles = @(
        Get-ChildItem -Path $script:GoldenRoot -Recurse -File -Filter '*.json' |
            Where-Object { $_.Name -in 'selection.json', 'expected.json' } |
            ForEach-Object {
                @{ RelativePath = $_.FullName.Substring($script:GoldenRoot.Length + 1) -replace '\\', '/' }
            } |
            Sort-Object { $_.RelativePath }
    )
}

Describe 'Maester 2.x golden fixtures' -Tag 'Golden' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        $goldenRoot = Join-Path $repoRoot 'powershell/tests/fixtures/golden'
        $exporter = Join-Path $repoRoot 'build/golden/Export-MtGoldenFixture.ps1'
        $freshRoot = Join-Path $TestDrive 'golden'

        # Re-derive every fixture in a separate process (the exporter imports the source module and a stub module).
        $pwsh = (Get-Process -Id $PID).Path
        $script:exporterOutput = & $pwsh -NoProfile -NonInteractive -File $exporter -OutputPath $freshRoot 2>&1
        $script:exporterExitCode = $LASTEXITCODE

        function Get-NormalizedContent {
            param([string] $Path)
            if (-not (Test-Path -LiteralPath $Path)) { return $null }
            return ([System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n")
        }

        $script:tagsAndBlocks = Get-Content -Path (Join-Path $goldenRoot 'tags-and-blocks.json') -Raw | ConvertFrom-Json
        $script:selection = Get-Content -Path (Join-Path $goldenRoot 'selection.json') -Raw | ConvertFrom-Json
    }

    It 'Export-MtGoldenFixture runs without errors' {
        $script:exporterExitCode | Should -Be 0 -Because ($script:exporterOutput | Out-String)
    }

    It '<RelativePath> matches what 2.x produces today' -ForEach $GoldenFiles {
        $committed = Get-NormalizedContent -Path (Join-Path $goldenRoot $RelativePath)
        $fresh = Get-NormalizedContent -Path (Join-Path $freshRoot $RelativePath)
        $fresh | Should -Not -BeNullOrEmpty

        if ($fresh -ne $committed) {
            $committedLines = $committed -split "`n"
            $freshLines = $fresh -split "`n"
            $line = 0
            while ($line -lt [Math]::Min($committedLines.Count, $freshLines.Count) -and $committedLines[$line] -eq $freshLines[$line]) { $line++ }
            $because = "the golden file drifted at line $($line + 1): committed '$($committedLines[$line])', now '$($freshLines[$line])'. " +
            'If the change is intended, run ./build/golden/Export-MtGoldenFixture.ps1 and commit the result'
            $fresh | Should -Be $committed -Because $because
        }
    }

    Context 'Maester 2.x tags (test attribute design, section 5.1)' {
        BeforeAll {
            # tags-and-blocks.json is the frozen 2.x snapshot. In 3.0 the built-in tests carry no taxonomy
            # tags, and Block and the tags on a result row changed on purpose, so neither is compared any
            # more. What must hold is that every 2.x tag still selects exactly the tests it selected: not
            # fewer, and not more, so a new test must not take a 2.x tag as one of its own tags.
            # MT1060 (drift) became the native family MT.1060: its four 2.x Its are one test.
            $script:renamedIds = @{ 'MT1060' = 'MT.1060' }
            $toSet = {
                param($entries)
                $byTag = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.SortedSet[string]]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($e in $entries) {
                    $id = if ($script:renamedIds.ContainsKey([string]$e.Id)) { $script:renamedIds[[string]$e.Id] } else { [string]$e.Id }
                    foreach ($tag in @($e.SelectionTags)) {
                        if (-not $byTag.ContainsKey($tag)) { $byTag[$tag] = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase) }
                        $null = $byTag[$tag].Add($id)
                    }
                }
                , $byTag
            }
            $script:was = & $toSet $script:tagsAndBlocks.Entries
            $script:fresh = (Get-Content -Path (Join-Path $freshRoot 'tags-and-blocks.json') -Raw | ConvertFrom-Json).Entries
            $script:now = & $toSet $script:fresh
            $script:legacyTable = Join-Path $repoRoot 'powershell/assets/Maester.LegacyTags.json'
        }

        It 'selects with every 2.x tag exactly the built-in tests it selected in 2.x' {
            $script:was.Count | Should -BeGreaterThan 900
            $problems = foreach ($tag in $script:was.Keys) {
                $expected = @($script:was[$tag]) -join ','
                $actual = if ($script:now.ContainsKey($tag)) { @($script:now[$tag]) -join ',' } else { '' }
                if ($expected -ne $actual) { "-Tag '$tag' selected '$expected' in 2.x and now selects '$actual'" }
            }
            @($problems) | Should -BeNullOrEmpty
        }

        It 'resolves every 2.x tag that is not a test ID to the same tests through the engine' {
            # The same question asked of the code path of Invoke-Maester -Tag (Resolve-MtNativePlan), one
            # plan per tag. A tag that is only the ID of its own test is covered by the test above.
            $cases = @(foreach ($tag in $script:was.Keys) {
                    $ids = @($script:was[$tag])
                    if ($ids.Count -eq 1 -and $ids[0] -eq $tag) { continue }
                    @{ Tag = $tag; Expected = $ids -join ',' }
                })
            $cases.Count | Should -BeGreaterThan 150
            $problems = InModuleScope Maester -Parameters @{ Cases = $cases } {
                param($Cases)
                $tests = @(Get-MtTestCatalog)
                $config = Resolve-MtRunConfig -Config @{}
                foreach ($case in $Cases) {
                    $selection = Resolve-MtSelection -RunConfig $config -Tag $case.Tag
                    $plan = @(Resolve-MtNativePlan -Test $tests -Selection $selection -RunConfig $config -IncludeTag $case.Tag -WarningAction SilentlyContinue)
                    $actual = @($plan | Where-Object { $_.ReasonCode -ne 'NotSelected' } | ForEach-Object { [string]$_.Test.Id } | Sort-Object -Unique { $_.ToLowerInvariant() })
                    $expected = @($case.Expected -split ',' | Sort-Object -Unique { $_.ToLowerInvariant() })
                    if (($actual -join ',') -ne ($expected -join ',')) { "-Tag '$($case.Tag)' should select '$($expected -join ',')' and selects '$($actual -join ',')'" }
                }
            }
            @($problems) | Should -BeNullOrEmpty
        }

        It 'Maester.LegacyTags.json is what build/golden/Export-MtLegacyTagTable.ps1 produces' {
            $out = Join-Path $TestDrive 'Maester.LegacyTags.json'
            $pwsh = (Get-Process -Id $PID).Path
            $output = & $pwsh -NoProfile -NonInteractive -File (Join-Path $repoRoot 'build/golden/Export-MtLegacyTagTable.ps1') -OutputPath $out 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
            (Get-NormalizedContent -Path $out) | Should -Be (Get-NormalizedContent -Path $script:legacyTable) -Because 'the table is generated from the frozen snapshots and never edited by hand'
        }

        It 'lists in Maester.LegacyTags.json only tests that exist, and gives the replacements of the design' {
            $table = Get-Content -Path $script:legacyTable -Raw | ConvertFrom-Json
            $ids = [System.Collections.Generic.HashSet[string]]::new([string[]]@($script:fresh | ForEach-Object { $_.Id }), [System.StringComparer]::OrdinalIgnoreCase)
            $missing = @($table.Tags | ForEach-Object { $_.Tests } | Where-Object { -not $ids.Contains($_) } | Select-Object -Unique)
            $missing | Should -BeNullOrEmpty
            $replacement = @{}
            foreach ($entry in $table.Tags) { if ($entry.PSObject.Properties['Replacement']) { $replacement[$entry.Tag] = $entry.Replacement } }
            $replacement['CA'] | Should -Be '-Feature conditional-access'
            $replacement['CISA'] | Should -Be '-Suite cisa'
            $replacement['EXO'] | Should -Be '-Product exchange'
            $replacement['Severity:High'] | Should -Be '-Severity High'
            $replacement.ContainsKey('MS.AAD.3.5') | Should -BeFalse
        }
    }

    It 'records every built-in ID once and the five run-time families' {
        $script:tagsAndBlocks._meta.DuplicateIds | Should -BeNullOrEmpty
        $script:tagsAndBlocks._meta.TestCount | Should -BeGreaterThan 700
        @($script:tagsAndBlocks._meta.FamilyPrefixes) | Should -Be @('MT.1024', 'MT.1033', 'MT.1034', 'MT.1059', 'MT1060')
        $script:tagsAndBlocks._meta.FallbackFiles | Should -BeNullOrEmpty
    }

    It 'freezes the Context quirk: MT.1022 is selected by CA but CA is missing from its result tags' {
        $entry = $script:tagsAndBlocks.Entries | Where-Object { $_.Id -eq 'MT.1022' }
        $entry.SelectionTags | Should -Contain 'CA'
        $entry.ResultTags | Should -Not -Contain 'CA'
    }

    It 'records the 3.0 selection fix: a PesterConfiguration ExcludeTag is honoured' {
        # 2.x discarded a caller's Filter.ExcludeTag (design section 7.1). The 'All' and 'Full' tags, which
        # selected nothing in 2.x, were removed in 3.0 and stop the run (see Invoke-Maester.Tests.ps1).
        $cases = @{}
        foreach ($c in $script:selection.Cases) { $cases[$c.Name] = $c }
        $cases['PesterConfiguration Filter.ExcludeTag EIDSCA'].Filter.ExcludeTag | Should -Contain 'EIDSCA'
        $cases['PesterConfiguration Filter.ExcludeTag EIDSCA'].SelectedCount | Should -Be $cases['ExcludeTag EIDSCA'].SelectedCount
    }
}
