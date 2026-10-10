BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:Generator = Join-Path $script:RepoRoot 'build/orca/Update-OrcaTests.ps1'
    $script:CommittedRoot = Join-Path $script:RepoRoot 'tests/orca'
    $script:FreshRoot = Join-Path $TestDrive 'orca'

    # Regenerate the native tests from the committed check-ORCA*.ps1 files, without downloading ORCA.
    $pwsh = (Get-Process -Id $PID).Path
    $script:GeneratorOutput = & $pwsh -NoProfile -NonInteractive -File $script:Generator -Offline -OutputPath $script:FreshRoot 2>&1
    $script:GeneratorExitCode = $LASTEXITCODE

    $script:Committed = @(Get-ChildItem -Path $script:CommittedRoot -File -Filter 'Test.ORCA.*' | Sort-Object Name)
    $script:Fresh = @(Get-ChildItem -Path $script:FreshRoot -File -Filter 'Test.ORCA.*' -ErrorAction SilentlyContinue | Sort-Object Name)
}

Describe 'ORCA generator' {
    It 'runs offline without errors' {
        $script:GeneratorExitCode | Should -Be 0 -Because ($script:GeneratorOutput | Out-String)
    }

    It 'produces the same set of native test files as tests/orca' {
        $script:Fresh.Count | Should -BeGreaterThan 0
        ($script:Fresh.Name -join "`n") | Should -Be ($script:Committed.Name -join "`n")
    }

    It 'produces exactly the committed content of every native test file' {
        $drifted = foreach ($file in $script:Committed) {
            $freshPath = Join-Path $script:FreshRoot $file.Name
            if (-not (Test-Path -LiteralPath $freshPath)) { continue }
            $committed = [System.IO.File]::ReadAllText($file.FullName) -replace "`r`n", "`n"
            $fresh = [System.IO.File]::ReadAllText($freshPath) -replace "`r`n", "`n"
            if ($committed -ne $fresh) { $file.Name }
        }
        @($drifted) | Should -BeNullOrEmpty -Because 'tests/orca is generated; edit build/orca/Update-OrcaTests.ps1 or build/orca/orca-test-metadata.json and run ./build/orca/Update-OrcaTests.ps1 -Offline'
    }

    It 'leaves no 2.x Pester wrappers or exported ORCA check functions' {
        @(Get-ChildItem -Path $script:CommittedRoot -File -Filter '*.Tests.ps1') | Should -BeNullOrEmpty
        Test-Path (Join-Path $script:RepoRoot 'powershell/public/orca') | Should -BeFalse
    }

    It 'generates tests that reach the ORCA cache only through the helper' {
        foreach ($file in ($script:Fresh | Where-Object Extension -EQ '.ps1')) {
            $text = [System.IO.File]::ReadAllText($file.FullName)
            $text | Should -Not -Match '\$__MtSession' -Because $file.Name
            $text | Should -Not -Match 'return\s*=\s*\$null' -Because $file.Name
            $text | Should -Not -Match 'Test-MtConnection' -Because "$($file.Name): the engine checks the services in the attribute"
            $text | Should -Match 'Get-MtOrcaCollection' -Because $file.Name
        }
    }

    It 'writes the typed attributes: the product as a key, no Category and no Tag' {
        foreach ($file in ($script:Fresh | Where-Object Extension -EQ '.ps1')) {
            $text = [System.IO.File]::ReadAllText($file.FullName)
            $text | Should -Match "(?m)^\s+Product = 'defender',\r?$" -Because $file.Name
            $text | Should -Not -Match '(?m)^\s+(Category|Tag|Preview) = ' -Because "$($file.Name): the 2.x tags select through Maester.LegacyTags.json"
        }
    }

    It 'emits the classification values of the metadata file, in the order of the attribute' {
        $metadataPath = Join-Path $TestDrive 'orca-test-metadata.json'
        $metadata = Get-Content (Join-Path $script:RepoRoot 'build/orca/orca-test-metadata.json') -Raw | ConvertFrom-Json
        $row = $metadata.Tests.'ORCA.100'
        foreach ($pair in @(
                @{ Name = 'RelatedProduct'; Value = @('exchange') }, @{ Name = 'Feature'; Value = 'anti-spam' }, @{ Name = 'Area'; Value = 'email-protection' },
                @{ Name = 'ResourceType'; Value = 'Policy' }, @{ Name = 'UserImpact'; Value = 'Low' }, @{ Name = 'ImplementationCost'; Value = 'Medium' },
                @{ Name = 'Mitre'; Value = @('T1566', 'T1566.001') })) {
            $row | Add-Member -NotePropertyName $pair.Name -NotePropertyValue $pair.Value -Force
        }
        $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath
        $out = Join-Path $TestDrive 'orca-values'
        $pwsh = (Get-Process -Id $PID).Path
        $output = & $pwsh -NoProfile -NonInteractive -File $script:Generator -Offline -OutputPath $out -MetadataPath $metadataPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)

        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $out 'Test.ORCA.100.ps1'), [ref] $null, [ref] $null)
        $attribute = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -eq 'MaesterTest' }, $true)
        $text = @{}
        foreach ($argument in $attribute.NamedArguments) { $text[$argument.ArgumentName] = $argument.Argument.Extent.Text }
        $text.RelatedProduct | Should -Be "'exchange'"
        $text.Feature | Should -Be "'anti-spam'"
        $text.Mitre | Should -Be "('T1566', 'T1566.001')"
        $names = @($attribute.NamedArguments.ArgumentName)
        $expected = 'Id', 'Title', 'Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'Severity', 'UserImpact', 'ImplementationCost', 'Mitre', 'Service'
        ($names | Select-Object -First $expected.Count) -join ',' | Should -Be ($expected -join ',')
        # A check without values is generated as it is in tests/orca.
        [System.IO.File]::ReadAllText((Join-Path $out 'Test.ORCA.101.ps1')) | Should -Be ([System.IO.File]::ReadAllText((Join-Path $script:CommittedRoot 'Test.ORCA.101.ps1')))
    }

    It 'has Maester metadata for every ORCA check' {
        $metadata = (Get-Content (Join-Path $script:RepoRoot 'build/orca/orca-test-metadata.json') -Raw | ConvertFrom-Json -AsHashtable).Tests
        $ids = @($script:Fresh | Where-Object Extension -EQ '.ps1' | ForEach-Object { $_.BaseName -replace '^Test\.', '' })
        foreach ($id in $ids) {
            $metadata.ContainsKey($id) | Should -BeTrue -Because "$id needs a Severity and Author in orca-test-metadata.json"
        }
        ($script:GeneratorOutput | Out-String) | Should -Not -Match 'orca-test-metadata\.json; using'
    }
}
