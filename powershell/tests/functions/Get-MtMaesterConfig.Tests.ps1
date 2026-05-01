Describe 'Get-MtMaesterConfig' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        $maesterTestsPath = Join-Path $PSScriptRoot '../../../tests'

        # Copy default config to test location to ensure it exists for the tests
        $testFolder = Join-Path 'TestDrive:' 'maester-config-tests'
        $null = New-Item -Path $testFolder -ItemType Directory
        Copy-Item -Path (Join-Path -Path $maesterTestsPath -ChildPath 'maester-config.json') -Destination (Join-Path -Path $testFolder -ChildPath 'maester-config.json')

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

        $result.ConfigSource | Should -Be 'maester-config.json'
    }

    Context 'Tenant-specific config' {
        BeforeAll {
            $tenantId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
            $tenantConfigPath = Join-Path $testFolder "maester-config.$tenantId.json"
            Set-Content -Path $tenantConfigPath -Value (@{
                GlobalSettings = @{
                    EmergencyAccessAccounts = @(
                        @{
                            Type = 'User'
                            UserPrincipalName = 'BreakGlass@tenant-specific.com'
                        }
                    )
                }
                TestSettings = @(
                    @{
                        Id = 'MT.1001'
                        Severity = 'Critical'
                        Title = 'Tenant-specific title'
                    }
                )
            } | ConvertTo-Json -Depth 5)
        }

        It 'Loads tenant-specific config when TenantId matches a file' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder; tenantId = $tenantId } {
                Get-MtMaesterConfig -Path $testFolder -TenantId $tenantId
            }

            $result | Should -Not -BeNullOrEmpty
            $result.GlobalSettings.EmergencyAccessAccounts[0].UserPrincipalName | Should -Be 'BreakGlass@tenant-specific.com'
            $sample = $result.TestSettings | Where-Object Id -eq 'MT.1001'
            $sample.Severity | Should -Be 'Critical'
        }

        It 'Falls back to default config when TenantId has no matching file' {
            $otherTenantId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder; otherTenantId = $otherTenantId } {
                Get-MtMaesterConfig -Path $testFolder -TenantId $otherTenantId
            }

            $result | Should -Not -BeNullOrEmpty
            # Should get the default config, not the tenant-specific one
            $result.GlobalSettings.EmergencyAccessAccounts | Should -BeNullOrEmpty
        }

        It 'Sets ConfigSource to the tenant-specific filename' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder; tenantId = $tenantId } {
                Get-MtMaesterConfig -Path $testFolder -TenantId $tenantId
            }

            $result.ConfigSource | Should -Be "maester-config.$tenantId.json"
        }

        It 'Sets ConfigSource to default filename when no tenant-specific config exists' {
            $otherTenantId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder; otherTenantId = $otherTenantId } {
                Get-MtMaesterConfig -Path $testFolder -TenantId $otherTenantId
            }

            $result.ConfigSource | Should -Be 'maester-config.json'
        }

        It 'Ignores TenantId that is not a valid GUID' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $testFolder } {
                Get-MtMaesterConfig -Path $testFolder -TenantId 'not-a-guid'
            }

            $result | Should -Not -BeNullOrEmpty
            # Should fall back to default config
            $result.ConfigSource | Should -Be 'maester-config.json'
        }

        It 'Uses direct file path when Path points to a file' {
            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ tenantConfigPath = $tenantConfigPath } {
                Get-MtMaesterConfig -Path $tenantConfigPath
            }

            $result | Should -Not -BeNullOrEmpty
            # Should use the file directly, not search for maester-config.json
            $result.GlobalSettings.EmergencyAccessAccounts[0].UserPrincipalName | Should -Be 'BreakGlass@tenant-specific.com'
        }

        AfterAll {
            Remove-Item -Path $tenantConfigPath -ErrorAction SilentlyContinue
        }
    }

    Context 'Using custom config' {
        It 'Merges custom config from <CustomFolderName>\maester-config.json' -ForEach @(
            @{
                ScenarioName     = 'uppercase'
                CustomFolderName = 'Custom'
                AccountId        = '11111111-1111-1111-1111-111111111111'
            }
            @{
                ScenarioName     = 'lowercase'
                CustomFolderName = 'custom'
                AccountId        = '22222222-2222-2222-2222-222222222222'
            }
            @{
                ScenarioName     = 'mixedcase'
                CustomFolderName = 'CUSTOM'
                AccountId        = '33333333-3333-3333-3333-333333333333'
            }
        ) {
            $customTestFolder = Join-Path -Path 'TestDrive:' -ChildPath "maester-config-tests-$ScenarioName"
            $null = New-Item -Path $customTestFolder -ItemType Directory -Force
            Copy-Item -Path (Join-Path -Path $maesterTestsPath -ChildPath 'maester-config.json') -Destination (Join-Path -Path $customTestFolder -ChildPath 'maester-config.json')

            $customFolderPath = Join-Path -Path $customTestFolder -ChildPath $CustomFolderName
            $null = New-Item -Path $customFolderPath -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $customFolderPath -ChildPath 'maester-config.json') -Value (@{
                GlobalSettings = @{
                    EmergencyAccessAccounts = @(
                        @{
                            Type = 'User'
                            Id   = $AccountId
                        }
                    )
                }
                TestSettings   = @(
                    @{
                        Id       = 'MT.1001'
                        Severity = 'Info'
                        Title    = 'Overridden Title from Custom Config'
                    }
                )
            } | ConvertTo-Json -Depth 5)

            $result = InModuleScope -ModuleName 'Maester' -Parameters @{ testFolder = $customTestFolder } {
                Get-MtMaesterConfig -Path $testFolder
            }

            $result | Should -Not -BeNullOrEmpty
            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.TestSettings.Count | Should -BeGreaterThan 0

            $result.GlobalSettings | Should -Not -BeNullOrEmpty
            $result.GlobalSettings.EmergencyAccessAccounts.Count | Should -BeGreaterThan 0
            $result.GlobalSettings.EmergencyAccessAccounts[0].Type | Should -Be 'User'
            $result.GlobalSettings.EmergencyAccessAccounts[0].Id | Should -Be $AccountId

            $sample = $result.TestSettings | Where-Object Id -eq 'MT.1001'
            $sample.Severity | Should -Be 'Info'
            #$sample.Title | Should -Be 'Overridden Title from Custom Config'
        }
    }
}
