Describe 'Get-MtMissingRequiredModule' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    Context 'No requirements' {
        It 'Returns an empty array for an empty RequiredModules array' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtMissingRequiredModule -RequiredModules @()
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'String entries' {
        It 'Returns the module name when a plain string module is not installed' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { $null } -ParameterFilter { $Name -eq 'NotInstalledModule' }
                $result = Get-MtMissingRequiredModule -RequiredModules @('NotInstalledModule')
                $result | Should -Be @('NotInstalledModule')
            }
        }

        It 'Returns nothing when a plain string module is installed' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } } -ParameterFilter { $Name -eq 'Pester' }
                $result = Get-MtMissingRequiredModule -RequiredModules @('Pester')
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Object entries with MinimumVersion' {
        It 'Returns nothing when the installed version satisfies MinimumVersion' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } } -ParameterFilter { $Name -eq 'Pester' }
                $result = Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = '5.0.0' })
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Flags a module installed below MinimumVersion' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'4.0.0' } } -ParameterFilter { $Name -eq 'Pester' }
                $result = Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = '5.0.0' })
                $result | Should -Be @('Pester (>= 5.0.0) - installed: 4.0.0')
            }
        }

        It 'Flags a module with MinimumVersion as missing when not installed at all' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { $null } -ParameterFilter { $Name -eq 'NotInstalledModule' }
                $result = Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'NotInstalledModule'; MinimumVersion = '1.0.0' })
                $result | Should -Be @('NotInstalledModule (>= 1.0.0)')
            }
        }

        It 'Ignores an unparsable MinimumVersion instead of throwing' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } } -ParameterFilter { $Name -eq 'Pester' }
                { Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = 'not-a-version' }) } | Should -Not -Throw
                $result = Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = 'not-a-version' })
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Picks the highest installed version when multiple versions are present' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module {
                    @(
                        [PSCustomObject]@{ Name = 'Pester'; Version = [version]'4.0.0' }
                        [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' }
                    )
                } -ParameterFilter { $Name -eq 'Pester' }
                $result = Get-MtMissingRequiredModule -RequiredModules @([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = '5.0.0' })
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Malformed entries' {
        It 'Skips a null entry' {
            InModuleScope -ModuleName 'Maester' {
                Mock Get-Module { [PSCustomObject]@{ Name = 'Pester'; Version = [version]'5.5.0' } } -ParameterFilter { $Name -eq 'Pester' }
                $result = Get-MtMissingRequiredModule -RequiredModules @($null, 'Pester')
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Skips an entry with a blank Name' {
            InModuleScope -ModuleName 'Maester' {
                $result = Get-MtMissingRequiredModule -RequiredModules @(@{ Name = '' })
                $result | Should -BeNullOrEmpty
            }
        }
    }
}
