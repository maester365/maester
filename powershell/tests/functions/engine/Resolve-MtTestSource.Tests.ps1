BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
    $script:legacyFolder = (Resolve-Path "$PSScriptRoot/../../fixtures/legacy-pester").Path
}

Describe 'Resolve-MtTestSource' {
    BeforeEach { Push-Location $TestDrive }
    AfterEach { Pop-Location }

    It 'Runs the built-in tests from the module and scans an explicit -Path for custom tests' {
        $folder = Join-Path $TestDrive 'explicit'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe 'C' { It 'C.1: c' { } }" | Set-Content (Join-Path $folder 'C.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder }
        $source.BuiltInFiles.Count | Should -BeGreaterThan 100
        $source.CustomFiles | Should -HaveCount 1
        $source.Error | Should -BeNullOrEmpty
    }

    It 'Warns and still runs the built-in tests when -Path does not exist' {
        $source = InModuleScope Maester { Resolve-MtTestSource -Path (Join-Path $TestDrive 'missing/tests/Maester') }
        $source.Error | Should -BeNullOrEmpty
        $source.BuiltInFiles.Count | Should -BeGreaterThan 100
        $source.CustomFiles | Should -HaveCount 0
        ($source.Messages | Where-Object Level -EQ 'Warning').Text | Should -BeLike '*does not exist*'
        $source.ConfigSearchPath | Should -Be (Resolve-Path $TestDrive).Path
    }

    It 'Fails with -SkipBuiltIn when -Path does not exist' {
        (InModuleScope Maester { Resolve-MtTestSource -Path (Join-Path $TestDrive 'missing') -SkipBuiltIn }).Error | Should -BeLike '*does not exist*'
    }

    It 'Runs no built-in tests with -SkipBuiltIn' {
        $folder = Join-Path $TestDrive 'skip'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe 'C' { It 'C.1: c' { } }" | Set-Content (Join-Path $folder 'C.Tests.ps1')
        $source = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtTestSource -Path $Folder -SkipBuiltIn }
        $source.BuiltInFiles | Should -HaveCount 0
        $source.CustomFiles | Should -HaveCount 1
    }

    It 'Does not scan an unrelated current folder when -Path is omitted' {
        $folder = Join-Path $TestDrive 'unrelated'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'src') -Force
        "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'src/Other.Tests.ps1')
        Push-Location $folder
        try { $source = InModuleScope Maester { Resolve-MtTestSource } } finally { Pop-Location }
        $source.CustomRoot | Should -BeNullOrEmpty
        $source.CustomFiles | Should -HaveCount 0
        ($source.Messages | Where-Object Level -EQ 'Information') | Should -Not -BeNullOrEmpty
    }

    It 'Scans the current folder when it is recognisably a Maester folder (<Marker>)' -ForEach @(
        @{ Marker = 'Custom folder' }
        @{ Marker = 'maester-config.json' }
        @{ Marker = 'test file' }
    ) {
        $folder = Join-Path $TestDrive ("maester-" + ($Marker -replace '\W', ''))
        $null = New-Item -ItemType Directory -Path $folder -Force
        switch ($Marker) {
            'Custom folder' { $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force; "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'Custom/X.Tests.ps1') }
            'maester-config.json' { '{}' | Set-Content (Join-Path $folder 'maester-config.json'); "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'X.Tests.ps1') }
            'test file' { "Describe 'X' { It 'X.1: x' { } }" | Set-Content (Join-Path $folder 'X.Tests.ps1') }
        }
        Push-Location $folder
        try { $source = InModuleScope Maester { Resolve-MtTestSource } } finally { Pop-Location }
        $source.CustomFiles | Should -HaveCount 1
    }

    It 'Treats files under the built-in root as built-in, never as custom' {
        $source = InModuleScope Maester { Resolve-MtTestSource -Path (Get-MtMaesterTestFolderPath) }
        $source.CustomFiles | Should -HaveCount 0
    }
}

Describe 'Get-MtSupersededTest' {
    BeforeAll {
        $script:expected = (Get-Content (Join-Path $script:legacyFolder 'expected.json') -Raw | ConvertFrom-Json).tests
        $script:result = InModuleScope Maester -Parameters @{ Folder = $script:legacyFolder } {
            $builtIn = @(Get-MtPesterFileInventory -Path @(Get-MtBuiltInPesterFile -BuiltInRoot (Get-MtMaesterTestFolderPath)))
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
            $file = Get-ChildItem (Join-Path $root 'cisa') -Recurse -Filter '*.Tests.ps1' | Select-Object -First 1
            $origin = Get-MtTestFileOrigin -File $file.FullName -Root $root -BuiltIn
            $origin.Source | Should -Be 'CISA'
            $origin.Suite | Should -Be 'CISA'
        }
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
            (Get-Content $manifest -Raw | ConvertFrom-Json).Source | Should -BeIn @('Maester', 'CISA', 'CIS', 'EIDSCA', 'ORCA') -Because $folder.Name
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
