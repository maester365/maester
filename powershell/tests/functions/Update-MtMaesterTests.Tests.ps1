BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Update-MtMaesterTests
}

Describe 'Update-MtMaesterTests' -Tag 'Unit' {
    BeforeEach {
        $script:root = (New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "mt-update-$([guid]::NewGuid())")).FullName
        $null = New-Item -ItemType Directory -Path (Join-Path $script:root 'tests'), (Join-Path $script:root 'testsuite')
        Set-Content -LiteralPath (Join-Path $script:root 'tests/Inside.Tests.ps1') -Value ''
        Set-Content -LiteralPath (Join-Path $script:root 'testsuite/Sibling.Tests.ps1') -Value ''
        $script:seen = @()

        $builtIn = Join-Path $script:root 'tests'
        Mock -ModuleName Maester Get-MtMaesterTestFolderPath { $builtIn }.GetNewClosure()
        Mock -ModuleName Maester Get-MtBuiltInPesterFile { @() }
        Mock -ModuleName Maester Get-MtTestCatalog { @() }
        Mock -ModuleName Maester Get-MtSupersededTest { [pscustomobject]@{ ExcludeFiles = @(); Items = @() } }
        Mock -ModuleName Maester Get-MtPesterFileInventory { @() }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'checks a folder whose name only starts like the built-in folder, and skips the built-in folder itself' {
        $null = Update-MtMaesterTests -Path $script:root 6>$null

        Should -Invoke Get-MtPesterFileInventory -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            @($Path).Count -eq 1 -and @($Path)[0] -like '*testsuite*Sibling.Tests.ps1'
        }
    }
}
