Describe 'Get-MtMaesterConfig' {
    BeforeAll {
        $maesterTestsPath = Join-Path $PSScriptRoot '../../../tests'

        # Copy default config to test location to ensure it exists for the tests
        $testFolder = Join-Path 'TestDrive:' 'maester-config-tests'
        $null = New-Item -Path $testFolder -ItemType Directory
        Copy-Item -Path "$maesterTestsPath/maester-config.json" -Destination "$testFolder/maester-config.json"
    }

    It 'Finds and reads a default config' {
        $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder } {
            Get-MtMaesterConfig -Path $testFolder
        }

        $result | Should -Not -BeNullOrEmpty

        $result.GlobalSettings | Should -Not -BeNullOrEmpty
        $result.GlobalSettings.EmergencyAccessAccounts | Should -BeNullOrEmpty

        $result.TestSettings.Count | Should -BeGreaterThan 0
        $sample = $result.TestSettings | Where-Object Id -eq 'MT.1001'
        $sample.Severity | Should -Not -Be 'Info'
        #$sample.Title | Should -Not -Be 'Overridden Title from Custom Config'
    }

    Context 'Using custom config' {
        BeforeAll {
            $customFolderPath = Join-Path $testFolder 'Custom'
            $null = New-Item -Path $customFolderPath -ItemType Directory
            Set-Content -Path "$customFolderPath/maester-config.json" -Value (@{
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

        It 'Merges custom config' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder } {
                Get-MtMaesterConfig -Path $testFolder
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
