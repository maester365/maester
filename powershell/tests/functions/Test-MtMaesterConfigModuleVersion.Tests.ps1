Describe 'Test-MtMaesterConfigModuleVersion' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    It 'warns when the running Maester module is newer than maester-config.json ModuleVersion' {
        InModuleScope -ModuleName 'Maester' {
            Mock Get-MtModuleVersion { [version]'2.1.0' }
            Mock Write-Warning {}

            $maesterConfig = [PSCustomObject]@{
                ModuleVersion = '2.0.0'
                ConfigSource  = 'maester-config.json'
            }

            $result = Test-MtMaesterConfigModuleVersion -MaesterConfig $maesterConfig

            $result | Should -BeTrue
            Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
                $Message -like '*updated the Maester module*' -and
                $Message -like '*maester-config.json*' -and
                $Message -like '*2.0.0*' -and
                $Message -like '*2.1.0*'
            }
        }
    }

    It 'does not warn when maester-config.json ModuleVersion is current or newer' -ForEach @(
        @{ ConfigModuleVersion = '2.1.0'; Scenario = 'current' }
        @{ ConfigModuleVersion = '2.2.0'; Scenario = 'newer' }
    ) {
        InModuleScope -ModuleName 'Maester' -Parameters @{ ConfigModuleVersion = $ConfigModuleVersion } {
            Mock Get-MtModuleVersion { [version]'2.1.0' }
            Mock Write-Warning {}

            $maesterConfig = [PSCustomObject]@{
                ModuleVersion = $ConfigModuleVersion
                ConfigSource  = 'maester-config.json'
            }

            $result = Test-MtMaesterConfigModuleVersion -MaesterConfig $maesterConfig

            $result | Should -BeFalse
            Should -Invoke Write-Warning -Exactly 0
        }
    }

    It 'fails gracefully when the version check cannot be completed' {
        InModuleScope -ModuleName 'Maester' {
            Mock Get-MtModuleVersion { throw 'version lookup failed' }
            Mock Write-Warning {}

            $maesterConfig = [PSCustomObject]@{
                ModuleVersion = '2.0.0'
                ConfigSource  = 'maester-config.json'
            }

            { Test-MtMaesterConfigModuleVersion -MaesterConfig $maesterConfig } | Should -Not -Throw
            Test-MtMaesterConfigModuleVersion -MaesterConfig $maesterConfig | Should -BeFalse
            Should -Invoke Write-Warning -Exactly 0
        }
    }
}
