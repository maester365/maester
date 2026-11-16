Describe 'Maester.LegacyIds.json' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        $legacyIdsPath = Join-Path $repoRoot 'powershell/assets/Maester.LegacyIds.json'
        $script:rawJson = [System.IO.File]::ReadAllText($legacyIdsPath)
        $script:table = $script:rawJson | ConvertFrom-Json

        # Fresh AST scan of the built-in tests: the static ID of every It name under tests/ (Custom excluded).
        $script:currentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $testsRoot = Join-Path $repoRoot 'tests'
        $customRoot = Join-Path $testsRoot 'Custom'
        $testFiles = Get-ChildItem -Path $testsRoot -Filter '*.Tests.ps1' -File -Recurse |
            Where-Object { -not $_.FullName.StartsWith($customRoot, [System.StringComparison]::OrdinalIgnoreCase) }
        foreach ($testFile in $testFiles) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($testFile.FullName, [ref] $tokens, [ref] $parseErrors)
            $itCommands = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'It'
                }, $true)
            foreach ($itCommand in $itCommands) {
                $nameAst = $itCommand.CommandElements[1]
                if ($nameAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $name = $nameAst.Value
                } elseif ($nameAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                    $name = $nameAst.Value
                } else {
                    continue
                }
                $name = ($name -replace '\s+', ' ').Trim()
                $colon = $name.IndexOf(':')
                $id = $null
                if ($colon -gt 0 -and $name.Substring(0, $colon) -match '^[A-Za-z0-9][A-Za-z0-9._\-]*$') {
                    $id = $name.Substring(0, $colon)
                } elseif ($name -notmatch '[<$]') {
                    $id = $name
                }
                if ($id) { $null = $script:currentIds.Add($id) }
            }
        }
        # Checks migrated to the native format are Test.<ID>.ps1 files.
        foreach ($nativeFile in (Get-ChildItem -Path $testsRoot -Recurse -File -Filter 'Test.*.ps1' | Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' })) {
            $null = $script:currentIds.Add(($nativeFile.Name -replace '^Test\.', '' -replace '\.ps1$', ''))
        }
    }

    It 'parses as JSON with the expected header' {
        $script:table | Should -Not -BeNullOrEmpty
        $script:table.SchemaVersion | Should -Be '1.0'
        $script:table.GeneratedFrom | Should -Match '^[0-9a-f]{40}$'
        $script:table.CurrentTestsHash | Should -Match '^[0-9a-f]{64}$'
        @($script:table.Entries).Count | Should -BeGreaterThan 0
    }

    It 'identifies the current built-in test inputs' {
        $filesByPath = [System.Collections.Generic.Dictionary[string, System.IO.FileInfo]]::new([System.StringComparer]::Ordinal)
        $inputFiles = Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Recurse -File |
            Where-Object {
                $_.FullName -notmatch '[\\/]Custom[\\/]' -and
                ($_.Name -like '*.Tests.ps1' -or $_.Name -like 'Test.*.ps1')
            }
        foreach ($file in $inputFiles) {
            $path = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
            $filesByPath.Add($path, $file)
        }
        $paths = [string[]]@($filesByPath.Keys)
        [System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
        $manifest = foreach ($path in $paths) {
            $content = [System.IO.File]::ReadAllText($filesByPath[$path].FullName) -replace "`r`n|`r", "`n"
            $fileHash = [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($content))
            ).ToLowerInvariant()
            "$path`0$fileHash"
        }
        $expectedHash = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData(
                [System.Text.Encoding]::UTF8.GetBytes(($manifest -join "`n"))
            )
        ).ToLowerInvariant()

        $script:table.CurrentTestsHash | Should -Be $expectedHash
    }

    It 'retains a previous mapping when its current target still exists' {
        $testRepo = Join-Path $TestDrive 'legacy-id-retention'
        $testRoot = Join-Path $testRepo 'tests'
        New-Item -ItemType Directory -Path (Join-Path $testRoot 'legacy') -Force | Out-Null
        $outputPath = Join-Path $testRepo 'Maester.LegacyIds.json'
        $generatorPath = Join-Path $repoRoot 'build/golden/Export-MtLegacyIdTable.ps1'

        $historicalTest = @(
            "Describe 'Legacy migration' {"
            "    It 'LEGACY-ID: Old title' {"
            '        Test-MtOld'
            '    }'
            '}'
        ) -join "`n"
        [System.IO.File]::WriteAllText(
            (Join-Path $testRoot 'legacy/Legacy.Tests.ps1'),
            $historicalTest,
            [System.Text.UTF8Encoding]::new($false)
        )

        foreach ($test in @(
                @{ Id = 'MT.1001'; Name = 'Test-MtCurrent'; Title = 'Current title' }
                @{ Id = 'MT.1002'; Name = 'Test-MtOld'; Title = 'Old title' }
            )) {
            $nativeTest = @(
                "function $($test.Name) {"
                "    [MaesterTest(Id = '$($test.Id)', Title = '$($test.Title)')]"
                '    param()'
                '    return $true'
                '}'
            ) -join "`n"
            [System.IO.File]::WriteAllText(
                (Join-Path $testRoot "Test.$($test.Id).ps1"),
                $nativeTest,
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        & git -C $testRepo init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the legacy ID test repository.' }
        & git -C $testRepo config user.name 'Maester Tests'
        if ($LASTEXITCODE -ne 0) { throw 'Could not configure the legacy ID test repository.' }
        & git -C $testRepo config user.email 'maester-tests@example.invalid'
        if ($LASTEXITCODE -ne 0) { throw 'Could not configure the legacy ID test repository.' }
        & git -C $testRepo add -- tests
        if ($LASTEXITCODE -ne 0) { throw 'Could not stage the legacy ID test fixtures.' }
        & git -C $testRepo commit --quiet -m 'Add legacy ID test fixtures'
        if ($LASTEXITCODE -ne 0) { throw 'Could not commit the legacy ID test fixtures.' }
        Remove-Item -LiteralPath (Join-Path $testRoot 'legacy/Legacy.Tests.ps1')

        $placeholderCommit = '0000000000000000000000000000000000000000'
        $priorTable = [ordered]@{
            SchemaVersion = '1.0'
            GeneratedFrom = $placeholderCommit
            Entries = @(
                [ordered]@{
                    LegacyId = 'LEGACY-ID'
                    CurrentId = 'MT.1001'
                    Rule = 'title'
                    FirstSeenCommit = $placeholderCommit
                    LastSeenCommit = $placeholderCommit
                    LastSeenFile = 'tests/legacy/Legacy.Tests.ps1'
                }
            )
            FamilyPrefixes = @()
        }
        [System.IO.File]::WriteAllText(
            $outputPath,
            (($priorTable | ConvertTo-Json -Depth 5) + "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        & $generatorPath -RepoRoot $testRepo -OutputPath $outputPath -WarningAction SilentlyContinue
        $generated = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
        ($generated.Entries | Where-Object LegacyId -EQ 'LEGACY-ID').CurrentId | Should -Be 'MT.1001'
    }

    It 'uses LF line endings' {
        $script:rawJson | Should -Not -Match "`r"
    }

    It 'finds current built-in IDs in tests/' {
        $script:currentIds.Count | Should -BeGreaterThan 100
    }

    It 'has every required field on every entry' {
        foreach ($entry in $script:table.Entries) {
            $entry.LegacyId | Should -Not -BeNullOrEmpty
            $entry.CurrentId | Should -Not -BeNullOrEmpty
            $entry.Rule | Should -BeIn @('title', 'function', 'prefix', 'manual', 'retired')
            $entry.FirstSeenCommit | Should -Match '^[0-9a-f]{40}$'
            $entry.LastSeenCommit | Should -Match '^[0-9a-f]{40}$'
            $entry.LastSeenFile | Should -BeLike 'tests/*'
        }
    }

    It 'has no LegacyId that is a current built-in ID' {
        $clashes = @($script:table.Entries | Where-Object { $script:currentIds.Contains($_.LegacyId) } | ForEach-Object { $_.LegacyId })
        $clashes | Should -BeNullOrEmpty
    }

    It 'maps every entry to a current built-in ID or retired' {
        $missing = @($script:table.Entries | Where-Object { $_.CurrentId -ne 'retired' -and -not $script:currentIds.Contains($_.CurrentId) } |
                ForEach-Object { "$($_.LegacyId) -> $($_.CurrentId)" })
        $missing | Should -BeNullOrEmpty
    }

    It 'marks retired entries with Rule retired or manual' {
        $bad = @($script:table.Entries | Where-Object { ($_.CurrentId -eq 'retired') -and ($_.Rule -notin 'retired', 'manual') })
        $bad | Should -BeNullOrEmpty
    }

    It 'has no duplicate LegacyId (case-insensitive)' {
        $duplicates = @($script:table.Entries | Group-Object { $_.LegacyId.ToLowerInvariant() } | Where-Object Count -GT 1 | ForEach-Object Name)
        $duplicates | Should -BeNullOrEmpty
    }

    It 'is sorted by LegacyId (ordinal)' {
        $ids = [string[]]@($script:table.Entries | ForEach-Object { $_.LegacyId })
        $sorted = [string[]]$ids.Clone()
        [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
        $ids | Should -Be $sorted
    }

    It 'has a non-empty FamilyPrefixes list of dotted prefixes' {
        @($script:table.FamilyPrefixes).Count | Should -BeGreaterThan 0
        foreach ($prefix in $script:table.FamilyPrefixes) {
            $prefix | Should -Match '^[A-Za-z]+\.?\d+\.$'
        }
    }
}
