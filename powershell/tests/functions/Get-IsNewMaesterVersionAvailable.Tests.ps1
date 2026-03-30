Describe 'Get-IsNewMaesterVersionAvailable' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/Get-MtLatestModuleVersion.ps1"
        . "$PSScriptRoot/../../internal/Get-MtModuleVersion.ps1"
        . "$PSScriptRoot/../../internal/Get-IsNewMaesterVersionAvailable.ps1"
    }

    Context 'When a newer version exists' {
        It 'returns true' {
            $latestVersion = [version]'2.5.0'

            Mock Get-MtModuleVersion { [version]'2.4.0' }
            Mock Get-MtLatestModuleVersion { $latestVersion }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            $result | Should -BeTrue
            Should -Invoke Get-MtModuleVersion -Exactly 1
            Should -Invoke Get-MtLatestModuleVersion -Exactly 1
        }

        It 'returns false when installed is equal to latest' {
            Mock Get-MtModuleVersion { [version]'2.0.0' }
            Mock Get-MtLatestModuleVersion { [version]'2.0.0' }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            $result | Should -BeFalse
        }

        It 'returns false when current version is not comparable (for example, Next)' {
            Mock Get-MtModuleVersion { 'Next' }
            Mock Get-MtLatestModuleVersion { [version]'2.0.0' }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            $result | Should -BeFalse
        }
    }

    Context 'When latest version cannot be determined' {
        It 'returns false' {
            Mock Get-MtModuleVersion { [version]'2.4.0' }
            Mock Get-MtLatestModuleVersion { $null }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            $result | Should -BeFalse
            Should -Invoke Get-MtLatestModuleVersion -Exactly 1
        }
    }

    Context 'When version lookup throws' {
        It 'returns false and does not throw' {
            Mock Get-MtModuleVersion { [version]'2.4.0' }
            Mock Get-MtLatestModuleVersion { throw 'Lookup failed' }
            Mock Write-Host {}

            { Get-IsNewMaesterVersionAvailable } | Should -Not -Throw
            Get-IsNewMaesterVersionAvailable | Should -BeFalse
        }
    }

    Context 'When installed version cannot be determined' {
        It 'returns false' {
            Mock Get-MtModuleVersion { $null }
            Mock Get-MtLatestModuleVersion { [version]'2.5.0' }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            $result | Should -BeFalse
        }
    }

    Context 'When current module version is a prerelease string' {
        It 'parses and compares prerelease versions correctly' {
            Mock Get-MtModuleVersion { '2.0.0-beta' }
            Mock Get-MtLatestModuleVersion { [version]'2.1.0' }
            Mock Write-Host {}

            $result = Get-IsNewMaesterVersionAvailable

            # 2.0.0-beta is normalized to 2.0.0 for deterministic comparison.
            $result | Should -BeTrue
        }
    }
}
