# The test builder page on maester.dev reads website/src/data/test-builder.json, which is generated from the
# schema, the registries and the rubric. This test fails when one of those changed and the file was not regenerated.
Describe 'Test builder data' {
    It 'has the Id and Control patterns of the schema written out in its code' {
        $root = (Resolve-Path "$PSScriptRoot/../../..").Path
        $schema = Import-PowerShellDataFile (Join-Path $root 'powershell/assets/MaesterTestSchema.psd1')
        $code = Get-Content (Join-Path $root 'website/src/components/TestBuilder/generate.js') -Raw
        $code | Should -Match ([regex]::Escape("const ID_PATTERN = /$($schema.IdPattern)/;"))
        $code | Should -Match ([regex]::Escape("const CONTROL_PATTERN = /$($schema.Properties.Control.Pattern)/;"))
    }

    It 'offers every setting a test can bind, and no connection setting' {
        $root = (Resolve-Path "$PSScriptRoot/../../..").Path
        $data = Get-Content (Join-Path $root 'website/src/data/test-builder.json') -Raw | ConvertFrom-Json
        $registry = (Import-PowerShellDataFile (Join-Path $root 'powershell/assets/MaesterSettings.psd1')).Settings
        @($data.settings.name | Sort-Object) | Should -Be @($registry.Keys | Sort-Object)
        $offered = @($data.settings | Where-Object { -not $_.connection -and $_.type -ne 'object' } | ForEach-Object name)
        # Every setting a built-in test binds is one the page offers.
        $bound = @(Get-ChildItem (Join-Path $root 'tests') -Recurse -Filter 'Test.*.ps1' | Select-String -Pattern "MaesterParameter\([^)]*Setting\s*=\s*'([^']+)'" -AllMatches |
                ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $bound | Should -Not -BeNullOrEmpty
        @($bound | Where-Object { $_ -notin $offered }) | Should -BeNullOrEmpty
        @($data.parameterNames | Where-Object name -EQ 'MaximumInactiveDays').type | Should -Be 'int'
    }

    It 'is up to date with the schema, the registries and the rubric' {
        $root = (Resolve-Path "$PSScriptRoot/../../..").Path
        $fresh = Join-Path ([System.IO.Path]::GetTempPath()) "test-builder-$([guid]::NewGuid()).json"
        try {
            & (Join-Path $root 'build/website/Update-MtTestBuilderData.ps1') -OutputPath $fresh 6>$null
            $expected = (Get-Content $fresh -Raw) -replace "`r`n", "`n"
            $actual = (Get-Content (Join-Path $root 'website/src/data/test-builder.json') -Raw) -replace "`r`n", "`n"
            $actual | Should -BeExactly $expected -Because 'run ./build/website/Update-MtTestBuilderData.ps1 and commit website/src/data/test-builder.json'
        }
        finally {
            Remove-Item $fresh -ErrorAction SilentlyContinue
        }
    }
}
