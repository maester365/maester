BeforeAll {
    $script:PackageScriptPath = Resolve-Path "$PSScriptRoot/../../../build/Build-MaesterPackage.ps1"
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    function Write-PackageTestFile {
        param (
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter(Mandatory)]
            [string] $Content
        )

        $Utf8Bom = [System.Text.UTF8Encoding]::new($true)
        [System.IO.File]::WriteAllText($Path, $Content, $Utf8Bom)
    }
}

AfterAll {
    Get-ChildItem -Path $script:RepoRoot -Directory -Filter '.tmp-maester-package-tests-*' |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Build-MaesterPackage' {
    It 'preserves source files, bundles test suites, and excludes local metadata' {
        $FixtureRoot = Join-Path $script:RepoRoot ".tmp-maester-package-tests-$([guid]::NewGuid())"
        $SourceRoot = Join-Path $FixtureRoot 'powershell'
        $TestsRoot = Join-Path $FixtureRoot 'tests'
        $OutputRoot = Join-Path $FixtureRoot 'publish/Maester'

        try {
            $null = New-Item -Path (Join-Path $SourceRoot 'public') -ItemType Directory -Force
            $null = New-Item -Path (Join-Path $SourceRoot 'internal') -ItemType Directory -Force
            $null = New-Item -Path (Join-Path $SourceRoot 'assets') -ItemType Directory -Force
            $null = New-Item -Path (Join-Path $TestsRoot 'Custom') -ItemType Directory -Force

            Write-PackageTestFile -Path (Join-Path $SourceRoot 'Maester.psm1') -Content 'function Get-TestThing { return $true }'
            Write-PackageTestFile -Path (Join-Path $SourceRoot 'Maester.psd1') -Content '@{ RootModule = ''Maester.psm1''; ModuleVersion = ''0.0.1'' }'
            Write-PackageTestFile -Path (Join-Path $SourceRoot 'public/Get-TestThing.ps1') -Content 'function Get-TestThing { return $true }'
            Write-PackageTestFile -Path (Join-Path $SourceRoot '.DS_Store') -Content 'local metadata'
            Write-PackageTestFile -Path (Join-Path $TestsRoot 'Custom/Sample.Tests.ps1') -Content 'Describe ''Sample'' { It ''passes'' { $true | Should -BeTrue } }'

            & $script:PackageScriptPath `
                -SourceRoot $SourceRoot `
                -TestsRoot $TestsRoot `
                -OutputRoot $OutputRoot *> $null

            (Join-Path $OutputRoot 'Maester.psm1') | Should -Exist
            (Join-Path $OutputRoot 'public/Get-TestThing.ps1') | Should -Exist
            (Join-Path $OutputRoot 'maester-tests/Custom/Sample.Tests.ps1') | Should -Exist
            (Join-Path $OutputRoot '.DS_Store') | Should -Not -Exist
        } finally {
            Remove-Item -LiteralPath $FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an output directory outside the repository' {
        $OutsidePath = Join-Path ([System.IO.Path]::GetTempPath()) "maester-package-tests-$([guid]::NewGuid())"

        {
            & $script:PackageScriptPath -OutputRoot $OutsidePath *> $null
        } | Should -Throw -ExpectedMessage '*outside the repository root*'
    }
}
