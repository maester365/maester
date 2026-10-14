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
