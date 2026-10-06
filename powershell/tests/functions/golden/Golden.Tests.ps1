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

    It 'reproduces the 2.x Block and tags of every built-in ID, native or Pester' {
        # tags-and-blocks.json is the frozen 2.x snapshot. A check migrated to the native format must keep
        # its Block and the tags -Tag selects on (design section 4); only its file and line change.
        $fresh = (Get-Content -Path (Join-Path $freshRoot 'tags-and-blocks.json') -Raw | ConvertFrom-Json).Entries
        $byId = @{}
        foreach ($e in $fresh) {
            $key = "$($e.Id)|$($e.Family)"
            if (-not $byId.ContainsKey($key)) { $byId[$key] = [System.Collections.Generic.List[object]]::new() }
            $byId[$key].Add($e)
        }
        # 2.x dropped the Describe tags of tests nested in a Context; native rows carry them (design section 5.3, item 4).
        $resultTagChanges = @('MT.1022', 'MT.1023')
        $problems = foreach ($e in $script:tagsAndBlocks.Entries) {
            $candidates = $byId["$($e.Id)|$($e.Family)"]
            if (-not $candidates -or $candidates.Count -eq 0) { "$($e.Id): missing"; continue }
            # An ID with several entries (a family with several Its) is matched entry by entry on its tags.
            $wanted = @($e.SelectionTags | Sort-Object -Unique) -join ','
            $now = $candidates | Where-Object { (@($_.SelectionTags | Sort-Object -Unique) -join ',') -eq $wanted } | Select-Object -First 1
            if (-not $now) { $now = $candidates[0] }
            $null = $candidates.Remove($now)
            if ($now.Block -ne $e.Block) { "$($e.Id): Block '$($e.Block)' is now '$($now.Block)'" }
            $was = @($e.SelectionTags | Sort-Object -Unique) -join ','
            $is = @($now.SelectionTags | Sort-Object -Unique) -join ','
            if ($was -ne $is) { "$($e.Id): selection tags '$was' are now '$is'" }
            if ($now.Format -ne 'Native' -and $e.Id -notin $resultTagChanges) {
                $wasResult = @($e.ResultTags | Sort-Object -Unique) -join ','
                $isResult = @($now.ResultTags | Sort-Object -Unique) -join ','
                if ($wasResult -ne $isResult) { "$($e.Id): result tags '$wasResult' are now '$isResult'" }
            }
        }
        @($problems) | Should -BeNullOrEmpty
        @($fresh).Count | Should -Be @($script:tagsAndBlocks.Entries).Count
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

    It 'records the 3.0 selection fixes: -Tag All and -Tag Full are the include switches, PesterConfiguration ExcludeTag is honoured' {
        # 2.x selected nothing for 'All' and 'Full' and discarded a caller's Filter.ExcludeTag (design section 7.1).
        $cases = @{}
        foreach ($c in $script:selection.Cases) { $cases[$c.Name] = $c }
        $cases['Tag All'].SelectedCount | Should -Be $cases['IncludePreview'].SelectedCount
        $cases['Tag Full'].SelectedCount | Should -Be $cases['IncludeLongRunning'].SelectedCount
        $cases['PesterConfiguration Filter.ExcludeTag EIDSCA'].Filter.ExcludeTag | Should -Contain 'EIDSCA'
        $cases['PesterConfiguration Filter.ExcludeTag EIDSCA'].SelectedCount | Should -Be $cases['ExcludeTag EIDSCA'].SelectedCount
    }
}
