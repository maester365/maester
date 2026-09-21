BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $expectations = @(
        @{
            Path     = '.devcontainer/devcontainer.json'
            Pattern  = '"modules":\s*"Pester==5\.7\.1,'
            Because  = 'fresh devcontainers must install the same Pester version as CI'
        }
        @{
            Path     = '.github/workflows/build-validation.yaml'
            Pattern  = 'Install-Module Pester -MinimumVersion 5\.7\.1 -MaximumVersion 5\.7\.1'
            Because  = 'CI must continue pinning the supported Pester baseline'
        }
        @{
            Path     = 'build/Test-PSModule.ps1'
            Pattern  = 'Import-Module Pester -RequiredVersion 5\.7\.1'
            Because  = 'module validation should load the supported Pester version explicitly'
        }
        @{
            Path     = 'build/Update-CommandReference.ps1'
            Pattern  = 'Install-Module Pester -RequiredVersion 5\.7\.1'
            Because  = 'doc generation should install the supported Pester version when missing'
        }
        @{
            Path     = 'build/Update-CommandReference.ps1'
            Pattern  = 'Import-Module Pester -RequiredVersion 5\.7\.1'
            Because  = 'doc generation should import the supported Pester version explicitly'
        }
        @{
            Path     = 'docs/examples/multi-tenant-pipeline.yml'
            Pattern  = "Install-Module 'Pester' -RequiredVersion 5\.7\.1"
            Because  = 'the published Azure DevOps example should not install Pester 6 by default'
        }
        @{
            Path     = 'powershell/tests/pester.ps1'
            Pattern  = 'Import-Module Pester -RequiredVersion 5\.7\.1'
            Because  = 'the repo test runner should import the supported Pester version explicitly'
        }
    )
}

Describe 'Pester version pinning' -ForEach @{ RepoRoot = $repoRoot; Expectations = $expectations } {
    It '<_.Path> contains the expected Pester 5.7.1 pin' -ForEach $Expectations {
        $content = Get-Content -Path (Join-Path $RepoRoot $_.Path) -Raw
        $content | Should -Match $_.Pattern -Because $_.Because
    }
}
