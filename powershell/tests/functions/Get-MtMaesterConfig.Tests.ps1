Describe 'Get-MtMaesterConfig' {
    BeforeAll {
        $maesterTestsPath = Join-Path $PSScriptRoot '../../../tests'
    }

    It 'Finds and reads a default config' {
        InModuleScope -ModuleName 'Maester' -Parameters @{ maesterTestsPath = $maesterTestsPath } {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ maesterTestsPath = $maesterTestsPath } {
                Get-MtMaesterConfig -Path $maesterTestsPath
            }

            $result | Should -Not -BeNullOrEmpty

            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.GlobalSettings.EmergencyAccessAccounts | Should -BeNullOrEmpty

            $result.TestSettings.Count | Should -BeGreaterThan 0
            $sample = $result.TestSettings | Where-Object Id -eq 'MT.1001'
            $sample.Severity | Should -Not -Be 'Info'
            #$sample.Title | Should -Not -Be 'Overridden Title from Custom Config'
        }
    }

    Context 'Using custom config' {
         BeforeAll {
            $customConfigPath = Join-Path $maesterTestsPath 'Custom/maester-config.json'
            Set-Content -Path $customConfigPath -Value (@{
                GlobalSettings = @{
                    EmergencyAccessAccounts = @(
                        @{
                            Type = 'User'
                            Id = '11111111-1111-1111-1111-111111111111'
                        }
                    )
                }
                TestSettings = @(
                    @{
                        Id = 'MT.1001'
                        Severity = 'Info'
                        Title = 'Overridden Title from Custom Config'
                    }
                )
            } | ConvertTo-Json -Depth 5)
        }

         AfterAll {
            if (Test-Path -Path $customConfigPath) {
                Remove-Item -Path $customConfigPath -Force
            }
        }

        It 'Merges custom config' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ maesterTestsPath = $maesterTestsPath } {
                Get-MtMaesterConfig -Path $maesterTestsPath
            }

            $result | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.TestSettings.Count | Should -BeGreaterThan 0

            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.GlobalSettings.EmergencyAccessAccounts.Count | Should -BeGreaterThan 0
            $result.GlobalSettings.EmergencyAccessAccounts[0].Type | Should -Be 'User'
            $result.GlobalSettings.EmergencyAccessAccounts[0].Id | Should -Be '11111111-1111-1111-1111-111111111111'

            $sample = $result.TestSettings | Where-Object Id -eq 'MT.1001'
            $sample.Severity | Should -Be 'Info'
            #$sample.Title | Should -Be 'Overridden Title from Custom Config'
        }
    }
}