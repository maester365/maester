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
        @($script:table.Entries).Count | Should -BeGreaterThan 0
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
