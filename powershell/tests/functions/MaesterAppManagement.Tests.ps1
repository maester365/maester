BeforeAll {
    # Import the functions for testing
    . "$PSScriptRoot/../../public/core/New-MtMaesterApp.ps1"
    . "$PSScriptRoot/../../public/core/Update-MtMaesterApp.ps1"
    . "$PSScriptRoot/../../public/core/Get-MtMaesterApp.ps1"
    . "$PSScriptRoot/../../internal/Set-MaesterAppPermissions.ps1"
    . "$PSScriptRoot/../../internal/Set-MaesterAppLogo.ps1"
    . "$PSScriptRoot/../../public/Get-MtGraphScope.ps1"
    . "$PSScriptRoot/../../public/core/Test-MtConnection.ps1"

    # Mock Invoke-AzRestMethod
    Mock Invoke-AzRestMethod {
        switch ($Uri) {
            { $_ -like '*applications*' -and $Method -eq 'GET' } {
                return @{
                    StatusCode = 200
                    Content = @{
                        value = @(
                            @{
                                id = 'test-object-id'
                                appId = 'test-app-id'
                                displayName = 'Test Maester App'
                                description = 'Test application'
                                tags = @('maester')
                                createdDateTime = '2024-01-01T00:00:00Z'
                                publisherDomain = 'test.com'
                                signInAudience = 'AzureADMyOrg'
                            }
                        )
                    } | ConvertTo-Json -Depth 3
                }
            }
            { $_ -like '*servicePrincipals*' -and $Method -eq 'GET' } {
                return @{
                    StatusCode = 200
                    Content = @{
                        value = @(
                            @{
                                id = 'test-sp-id'
                                appId = 'test-app-id'
                                servicePrincipalType = 'Application'
                            }
                        )
                    } | ConvertTo-Json -Depth 3
                }
            }
            default {
                return @{
                    StatusCode = 200
                    Content = '{"value": []}'
                }
            }
        }
    }

    # Mock Test-MtConnection
    Mock Test-MtConnection { return $true }

    # Mock Test-Path for logo
    Mock Test-Path { return $true } -ParameterFilter { $Path -like '*maester.png' }

    # Mock file operations
    Mock Join-Path { return '/mock/path/maester.png' }
}

Describe 'Maester App Management Cmdlets' {
    Context 'Get-MtMaesterApp' {
        It 'Should return Maester applications' {
            $result = Get-MtMaesterApp
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'Test Maester App'
            $result.ApplicationId | Should -Be 'test-app-id'
        }

        It 'Should filter by ApplicationId' {
            $result = Get-MtMaesterApp -ApplicationId 'test-app-id'
            $result | Should -Not -BeNullOrEmpty
            $result.ApplicationId | Should -Be 'test-app-id'
        }
    }

    Context 'New-MtMaesterApp parameter validation' {
        It 'Should use default name when none provided' {
            $mockApp = @{
                id = 'test-id'
                appId = 'test-app-id'
                displayName = 'Maester DevOps Account'
            }

            Mock Invoke-AzRestMethod {
                return @{
                    StatusCode = 201
                    Content = $mockApp | ConvertTo-Json
                }
            } -ParameterFilter { $Method -eq 'POST' -and $Uri -like '*applications*' }

            Mock Set-MaesterAppPermissions { }
            Mock Set-MaesterAppLogo { }

            New-MtMaesterApp -WhatIf
            # WhatIf should not actually create anything, just verify parameters are processed
            Assert-MockCalled Test-MtConnection -Exactly 1
        }

        It 'Should accept custom name' {
            New-MtMaesterApp -Name 'Custom App Name' -WhatIf
            Assert-MockCalled Test-MtConnection -Exactly 1
        }

        It 'Should pass scope parameters to Get-MtGraphScope' {
            Mock Get-MtGraphScope { return @('Directory.Read.All') }
            New-MtMaesterApp -SendMail -Privileged -WhatIf
            Assert-MockCalled Get-MtGraphScope -Exactly 1 -ParameterFilter {
                $SendMail -eq $true -and $Privileged -eq $true
            }
        }
    }

    Context 'Update-MtMaesterApp parameter validation' {
        It 'Should accept ApplicationId from pipeline' {
            $testApp = [PSCustomObject]@{
                ApplicationId = 'test-app-id'
                DisplayName = 'Test App'
            }

            $testApp | Update-MtMaesterApp -WhatIf
            Assert-MockCalled Test-MtConnection -Exactly 1
        }
    }

    Context 'Error handling' {
        It 'Should throw when not connected to Graph' {
            Mock Test-MtConnection { return $false }

            { Get-MtMaesterApp } | Should -Throw '*Please connect to Microsoft Graph first*'
        }
    }
}