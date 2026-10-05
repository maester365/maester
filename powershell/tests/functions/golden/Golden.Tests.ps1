BeforeDiscovery {
    $script:GoldenRoot = (Resolve-Path "$PSScriptRoot/../../fixtures/golden").Path
    $script:GoldenFiles = @(
        Get-ChildItem -Path $script:GoldenRoot -Recurse -File -Filter '*.json' |
            Where-Object { $_.Name -in 'tags-and-blocks.json', 'selection.json', 'expected.json' } |
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

    It 'freezes the selection quirks: -Tag All and -Tag Full select nothing, PesterConfiguration ExcludeTag is discarded' {
        ($script:selection.Cases | Where-Object Name -EQ 'Tag All').SelectedCount | Should -Be 0
        ($script:selection.Cases | Where-Object Name -EQ 'Tag Full').SelectedCount | Should -Be 0
        $pcCase = $script:selection.Cases | Where-Object Name -EQ 'PesterConfiguration Filter.ExcludeTag EIDSCA'
        $pcCase.Filter.ExcludeTag | Should -Not -Contain 'EIDSCA'
    }
}
