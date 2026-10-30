BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    $script:legacyFolder = (Resolve-Path "$PSScriptRoot/../../fixtures/legacy-pester").Path
}

Describe 'Resolve-MtTestSource' {
    BeforeEach { Push-Location $TestDrive }
    AfterEach { Pop-Location }

    It 'Runs the built-in tests from the module and scans an explicit -Path for custom tests' {
        $folder = Join-Path $TestDrive 'explicit/Custom'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe 'C' { It 'C.1: c' { } }" | Set-Content (Join-Path $folder 'C.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder }
        # Every built-in check is a native test now; they come from the catalog, not from Pester files.
        $source.BuiltInFiles | Should -HaveCount 0
        $source.BuiltInRoot | Should -Not -BeNullOrEmpty
        $source.CustomFiles | Should -HaveCount 1
        $source.Error | Should -BeNullOrEmpty
    }

    It 'Warns and still runs the built-in tests when -Path does not exist' {
        $source = InModuleScope Maester { Resolve-MtTestSource -Path (Join-Path $TestDrive 'missing/tests/Maester') }
        $source.Error | Should -BeNullOrEmpty
        $source.BuiltInRoot | Should -Not -BeNullOrEmpty
        $source.CustomFiles | Should -HaveCount 0
        ($source.Messages | Where-Object Level -EQ 'Warning').Text | Should -BeLike '*does not exist*'
        $source.ConfigSearchPath | Should -Be (Resolve-Path $TestDrive).Path
    }

    It 'Fails with -SkipBuiltIn when -Path does not exist' {
        (InModuleScope Maester { Resolve-MtTestSource -Path (Join-Path $TestDrive 'missing') -SkipBuiltIn }).Error | Should -BeLike '*does not exist*'
    }

    It 'Runs no built-in tests with -SkipBuiltIn' {
        $folder = Join-Path $TestDrive 'skip/Custom'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe 'C' { It 'C.1: c' { } }" | Set-Content (Join-Path $folder 'C.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder -SkipBuiltIn }
        $source.BuiltInFiles | Should -HaveCount 0
        $source.CustomFiles | Should -HaveCount 1
    }

    It 'Scans only the Custom folder of the current folder when -Path is omitted' {
        $folder = Join-Path $TestDrive 'cwd-custom'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'custom/entra'), (Join-Path $folder 'Maester'), (Join-Path $folder 'src') -Force
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'custom/entra/X.Tests.ps1')
        '' | Set-Content (Join-Path $folder 'custom/Test.CONTOSO.1.ps1')
        "Describe 'S' { It 'S.1: s' { } }" | Set-Content (Join-Path $folder 'Maester/Stale.Tests.ps1')
        '' | Set-Content (Join-Path $folder 'src/Test.OTHER.1.ps1')
        '' | Set-Content (Join-Path $folder 'Test.ROOT.1.ps1')
        Push-Location $folder
        try { $source = InModuleScope Maester { Resolve-MtTestSource } } finally { Pop-Location }
        $source.CustomRoot | Should -Be (Join-Path (Resolve-Path $folder).Path 'custom')
        $source.ConfigSearchPath | Should -Be (Resolve-Path $folder).Path
        $source.CustomFiles | Should -HaveCount 1
        $source.CustomNativeFiles | Should -HaveCount 1
        $source.CustomNativeFiles[0] | Should -BeLike '*Test.CONTOSO.1.ps1'
    }

    It 'Scans no folder when -Path is omitted and the current folder has no Custom folder (<Marker>)' -ForEach @(
        @{ Marker = 'unrelated' }
        @{ Marker = 'maester-config.json' }
        @{ Marker = 'test file' }
    ) {
        $folder = Join-Path $TestDrive ("nocustom-" + ($Marker -replace '\W', ''))
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'src') -Force
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'src/Other.Tests.ps1')
        switch ($Marker) {
            'maester-config.json' { '{}' | Set-Content (Join-Path $folder 'maester-config.json') }
            'test file' { "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'X.Tests.ps1'); '' | Set-Content (Join-Path $folder 'Test.X.1.ps1') }
        }
        Push-Location $folder
        try { $source = InModuleScope Maester { Resolve-MtTestSource } } finally { Pop-Location }
        $source.CustomRoot | Should -BeNullOrEmpty
        $source.CustomFiles | Should -HaveCount 0
        $source.CustomNativeFiles | Should -HaveCount 0
        ($source.Messages | Where-Object Level -EQ 'Information') | Should -Not -BeNullOrEmpty
    }

    It 'Scans the current folder when it is itself a Custom folder' {
        $folder = Join-Path $TestDrive 'self/Custom'
        $null = New-Item -ItemType Directory -Path $folder -Force
        '' | Set-Content (Join-Path $folder 'Test.CONTOSO.1.ps1')
        Push-Location $folder
        try { $source = InModuleScope Maester { Resolve-MtTestSource } } finally { Pop-Location }
        $source.CustomNativeFiles | Should -HaveCount 1
    }

    It 'Finds native tests anywhere under -Path, but Pester-format tests only in a Custom folder' {
        $folder = Join-Path $TestDrive 'mixed'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'entra'), (Join-Path $folder 'Maester'), (Join-Path $folder 'tests/Custom') -Force
        '' | Set-Content (Join-Path $folder 'entra/Test.CONTOSO.1.ps1')
        '' | Set-Content (Join-Path $folder 'Test.CONTOSO.2.ps1')
        "Describe 'S' { It 'S.1: s' { } }" | Set-Content (Join-Path $folder 'Maester/Stale.Tests.ps1')
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'tests/Custom/X.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder }
        $source.CustomNativeFiles | Should -HaveCount 2
        $source.CustomFiles | Should -HaveCount 1
        $source.CustomFiles[0] | Should -BeLike '*Custom*X.Tests.ps1'
        ($source.Messages | Where-Object Level -EQ 'Warning').Text | Should -BeLike '*1 Pester-format test file(s)*not in a Custom folder*'
    }

    It 'Runs every Pester-format test under a -Path that is a Custom folder or inside one' {
        $folder = Join-Path $TestDrive 'inside/Custom/entra'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'X.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder -SkipBuiltIn }
        $source.CustomFiles | Should -HaveCount 1
        $source.Messages | Should -HaveCount 0
    }

    It 'Runs a Pester-format test file given as -Path wherever it is' {
        $file = Join-Path $TestDrive 'single/X.Tests.ps1'
        $null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content $file
        $source = InModuleScope Maester -Parameters @{ File = $file } { Resolve-MtTestSource -Path $File -SkipBuiltIn }
        $source.CustomFiles | Should -HaveCount 1
    }

    It 'Looks at most three folder levels deep' {
        $folder = Join-Path $TestDrive 'deep'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'a/b/c/d') -Force
        '' | Set-Content (Join-Path $folder 'a/b/c/Test.CONTOSO.3.ps1')
        '' | Set-Content (Join-Path $folder 'a/b/c/d/Test.CONTOSO.4.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder -SkipBuiltIn }
        $source.CustomNativeFiles | Should -HaveCount 1
        $source.CustomNativeFiles[0] | Should -BeLike '*Test.CONTOSO.3.ps1'
    }

    It 'Treats files under the built-in root as built-in, never as custom' {
        $source = InModuleScope Maester { Resolve-MtTestSource -Path (Get-MtMaesterTestFolderPath) }
        $source.CustomFiles | Should -HaveCount 0
    }

    It 'Treats only the Custom folder directly under the built-in root as custom, even when the root is inside a Custom folder' {
        $root = Join-Path $TestDrive 'Custom/builtin'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'custom'), (Join-Path $root 'entra/Custom') -Force
        '' | Set-Content (Join-Path $root 'custom/Test.CONTOSO.5.ps1')
        '' | Set-Content (Join-Path $root 'entra/Test.MT.9998.ps1')
        '' | Set-Content (Join-Path $root 'entra/Custom/Test.MT.9999.ps1')
        Mock -ModuleName Maester Get-MtMaesterTestFolderPath { Join-Path $TestDrive 'Custom/builtin' }
        $source = InModuleScope Maester -Parameters @{ Folder = $root } { Resolve-MtTestSource -Path $Folder -SkipBuiltIn }
        $source.CustomNativeFiles | Should -HaveCount 1
        $source.CustomNativeFiles[0] | Should -BeLike '*Test.CONTOSO.5.ps1'
    }
}

Describe 'Get-MtCustomTestFile' {
    It 'Scans a filesystem root as itself, not as an empty or drive-relative path' {
        Mock -ModuleName Maester Get-ChildItem { }
        $root = [System.IO.Path]::GetPathRoot($TestDrive)
        $null = InModuleScope Maester -Parameters @{ Root = $root } { Get-MtCustomTestFile -Root $Root -Format Native }
        Should -Invoke -ModuleName Maester Get-ChildItem -Times 1 -Exactly -ParameterFilter { $LiteralPath -contains [System.IO.Path]::GetPathRoot($TestDrive) }
    }
}

Describe 'Get-MtSupersededTest' {
    BeforeAll {
        $script:expected = (Get-Content (Join-Path $script:legacyFolder 'expected.json') -Raw | ConvertFrom-Json).tests
        $script:result = InModuleScope Maester -Parameters @{ Folder = $script:legacyFolder } {
            # Every built-in check is native, so the built-in Pester inventory is empty and the IDs come from the catalog.
            $builtInFiles = @(Get-MtBuiltInPesterFile -BuiltInRoot (Get-MtMaesterTestFolderPath))
            $builtIn = @(if ($builtInFiles.Count -gt 0) { Get-MtPesterFileInventory -Path $builtInFiles })
            $custom = @(Get-MtPesterFileInventory -Path $Folder)
            [pscustomobject]@{ Custom = $custom; Superseded = Get-MtSupersededTest -CustomInventory $custom -BuiltInInventory $builtIn -BuiltInId @(Get-MtTestCatalog | ForEach-Object { $_.Id }) }
        }
    }

    It 'Supersedes exactly the tests the fixture expects to be superseded' {
        # The fixture lists the expanded instances of a family; static discovery sees its literal prefix.
        $normalise = { param($id) if ($id -match '^(MT\.1024|MT\.1033|MT\.1034|MT\.1059|MT1060)\.') { "$($Matches[1])." } else { $id } }
        $expectedIds = @($script:expected | Where-Object disposition -EQ 'Superseded' | ForEach-Object { & $normalise $_.expectedId }) | Sort-Object -Unique
        $actualIds = @($script:result.Superseded.Items | ForEach-Object { & $normalise $_.Id }) | Sort-Object -Unique
        $actualIds | Should -Be $expectedIds
        # Nothing the fixture expects to run is superseded.
        $runIds = @($script:expected | Where-Object disposition -EQ 'Run' | ForEach-Object { $_.expectedId })
        @($actualIds | Where-Object { $_ -in $runIds }) | Should -HaveCount 0
    }

    It 'Matches a current built-in ID, a previous ID and a family prefix' {
        $script:result.Superseded.Items.MatchedBy | Sort-Object -Unique | Should -Be @('BuiltInId', 'FamilyPrefix', 'PreviousId')
    }

    It 'Excludes a file whose every test is superseded as a whole' {
        $script:result.Superseded.ExcludeFiles | Where-Object { $_ -like '*Stale.EntraRecommendations.Tests.ps1' } | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-MtTestFileOrigin' {
    It 'Takes Source and Suite from the nearest suite.json of a built-in file' {
        InModuleScope Maester {
            $root = Get-MtMaesterTestFolderPath
            # CISA is fully native (Test.<ID>.ps1); the origin comes from suite.json whatever the file format.
            $file = Get-ChildItem (Join-Path $root 'cisa') -Recurse -Filter '*.ps1' | Select-Object -First 1
            $file | Should -Not -BeNullOrEmpty
            $origin = Get-MtTestFileOrigin -File $file.FullName -Root $root -BuiltIn
            $origin.Source | Should -Be 'CISA'
            $origin.Suite | Should -Be 'CISA'
        }
    }

    It 'Gives native built-in tests the Source and Suite of their suite folder in the catalog' {
        $native = @(Get-MtTest | Where-Object { $_.BuiltIn -and $_.File -like '*cisa*' }) | Select-Object -First 1
        $native | Should -Not -BeNullOrEmpty
        $native.Format | Should -Be 'Native'
        $native.Source | Should -Be 'CISA'
        $native.Suite | Should -Be 'CISA'
    }

    It 'Gives a custom file without suite.json Source Custom' {
        $file = Join-Path $TestDrive 'origin/X.Tests.ps1'
        $null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
        '' | Set-Content $file
        $origin = InModuleScope Maester -Parameters @{ File = $file; Root = (Split-Path $file) } { Get-MtTestFileOrigin -File $File -Root $Root }
        $origin.Source | Should -Be 'Custom'
        $origin.Suite | Should -Be 'Custom'
    }

    It 'Has a suite.json with a known Source for every built-in suite folder' {
        $root = InModuleScope Maester { Get-MtMaesterTestFolderPath }
        foreach ($folder in Get-ChildItem $root -Directory | Where-Object Name -NE 'Custom') {
            $manifest = Join-Path $folder.FullName 'suite.json'
            $manifest | Should -Exist -Because $folder.Name
            (Get-Content $manifest -Raw | ConvertFrom-Json).Source | Should -BeIn @('Maester', 'CISA', 'CIS', 'EIDSCA', 'ORCA', 'ASD') -Because $folder.Name
        }
    }
}

Describe 'Install-MaesterTests and Update-MaesterTests' {
    It 'Install-MaesterTests writes only the Custom README and a config template, and never overwrites' {
        $folder = Join-Path $TestDrive 'install'
        Install-MaesterTests -Path $folder 6>$null
        (Get-ChildItem $folder -Recurse -File | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('maester-config.json', 'README.md')
        Get-ChildItem $folder -Recurse -Filter '*.Tests.ps1' | Should -BeNullOrEmpty
        '{ "mine": true }' | Set-Content (Join-Path $folder 'maester-config.json')
        Install-MaesterTests -Path $folder 6>$null
        Get-Content (Join-Path $folder 'maester-config.json') -Raw | Should -BeLike '*mine*'
    }

    It 'Update-MaesterTests removes copies of built-in tests, keeps Custom and mixed files, and supports -WhatIf' {
        $folder = Join-Path $TestDrive 'update'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Maester'), (Join-Path $folder 'Custom') -Force
        "Describe 'S' { It 'MT.1001: copy' { } }" | Set-Content (Join-Path $folder 'Maester/Copy.Tests.ps1')
        "Describe 'S' { It 'MS.AAD.7.1: old copy' { } }" | Set-Content (Join-Path $folder 'Maester/Old.Tests.ps1')
        "Describe 'S' { It 'CONTOSO.1: mine' { }; It 'MT.1002: copy' { } }" | Set-Content (Join-Path $folder 'Maester/Mixed.Tests.ps1')
        "Describe 'S' { It 'MT.1003: kept in Custom' { } }" | Set-Content (Join-Path $folder 'Custom/InCustom.Tests.ps1')

        $null = Update-MaesterTests -Path $folder -WhatIf 6>$null
        Get-ChildItem $folder -Recurse -Filter '*.Tests.ps1' | Should -HaveCount 4

        $result = Update-MaesterTests -Path $folder -Force -WarningAction SilentlyContinue 6>$null
        $result.RemovedFiles | Should -HaveCount 2
        (Get-ChildItem $folder -Recurse -Filter '*.Tests.ps1' | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @('InCustom.Tests.ps1', 'Mixed.Tests.ps1')
    }
}
