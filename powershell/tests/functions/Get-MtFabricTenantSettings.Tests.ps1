BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    $script:fabricTestTokenKey = [byte[]](0..15)
    $script:encryptedFabricTestToken = '76492d1116743f0423413b16050a5345MgB8ADgAbwBvADMAWgBoAGcAYQBPAEYAMwBhAHQARgBCAEYAeQA3AHgAbQBlAFEAPQA9AHwAYwAwAGYANwBlADUAMAA1ADcANwBmAGUANABmAGMAMQAxAGIAMgAyADMANAA4ADcANQA5AGMAZAA5ADQAMwAyADEAOABjADQAOQBjAGYAOAA4ADMAZAA2AGEAZgA1ADcAMAA1ADEANABkADIANABlAGEANABhADgAOABkAGUAZQBhADAAYwAwADIAYgBiADgAMQBkAGQAMAA1AGEAMgAzAGIAYQA3ADQAMgBlAGUAMAA3AGMANQA1AGMAMwA2ADIANwA1ADgAZgBiAGUAOQBlADcAYgBlAGYAOQA2ADAAMAA4AGYAZgBkADQANAA5AGMAOQA2AGQAMQAyAGEANgA1ADQANQAwADcAMABhADkAYQAxADIAMwBhADMAMQAxAGIAZQBjADgAYgA4ADYAMgBkADIANABlAGMANgBlADcAMQA='

    if (-not (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue)) {
        function global:Get-AzAccessToken {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ResourceUrl', Justification = 'Stub signature only; Mock binds -ResourceUrl from it.')]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'AsSecureString', Justification = 'Stub signature only; Mock binds -AsSecureString from it.')]
            param(
                [string] $ResourceUrl,
                [switch] $AsSecureString
            )
        }
        $script:removeAzStub = $true
    }
}

AfterAll {
    if ($script:removeAzStub) {
        Remove-Item -Path Function:\Get-AzAccessToken -ErrorAction SilentlyContinue
    }
}

Describe 'Get-MtFabricTenantSettings' {
    BeforeEach {
        InModuleScope Maester { $__MtSession.FabricCache = @{} }
    }

    It 'requests a secure Fabric token and returns the tenant settings' {
        Mock -ModuleName Maester Get-AzAccessToken {
            [pscustomobject]@{ Token = ConvertTo-SecureString -String $script:encryptedFabricTestToken -Key $script:fabricTestTokenKey }
        }
        Mock -ModuleName Maester Invoke-RestMethod {
            [pscustomobject]@{
                value           = @(
                    [pscustomobject]@{ settingName = 'FirstSetting' }
                    [pscustomobject]@{ settingName = 'SecondSetting' }
                )
                continuationUri = $null
            }
        }

        $settings = @(InModuleScope Maester { Get-MtFabricTenantSettings })

        $settings | Should -HaveCount 2
        $settings[0].settingName | Should -Be 'FirstSetting'
        Should -Invoke Get-AzAccessToken -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $ResourceUrl -eq 'https://api.fabric.microsoft.com' -and $AsSecureString
        }
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Method -eq 'Get' -and
            $Uri -eq 'https://api.fabric.microsoft.com/v1/admin/tenantsettings' -and
            $Authentication -eq 'Bearer' -and
            $Token -is [securestring]
        }
    }

    It 'follows continuationUri and combines settings from every page' {
        Mock -ModuleName Maester Get-AzAccessToken {
            [pscustomobject]@{ Token = ConvertTo-SecureString -String $script:encryptedFabricTestToken -Key $script:fabricTestTokenKey }
        }
        Mock -ModuleName Maester Invoke-RestMethod {
            if ($Uri -eq 'https://api.fabric.microsoft.com/v1/admin/tenantsettings') {
                [pscustomobject]@{
                    value           = @([pscustomobject]@{ settingName = 'FirstSetting' })
                    continuationUri = 'https://api.fabric.microsoft.com/v1/admin/tenantsettings?continuationToken=page2'
                }
            }
            else {
                [pscustomobject]@{
                    value           = @([pscustomobject]@{ settingName = 'SecondSetting' })
                    continuationUri = $null
                }
            }
        }

        $settings = @(InModuleScope Maester { Get-MtFabricTenantSettings })

        $settings | Should -HaveCount 2
        $settings[0].settingName | Should -Be 'FirstSetting'
        $settings[1].settingName | Should -Be 'SecondSetting'
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.fabric.microsoft.com/v1/admin/tenantsettings'
        }
        Should -Invoke Invoke-RestMethod -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.fabric.microsoft.com/v1/admin/tenantsettings?continuationToken=page2'
        }
    }

    It 'returns no settings when the response has no value property' {
        Mock -ModuleName Maester Get-AzAccessToken {
            [pscustomobject]@{ Token = ConvertTo-SecureString -String $script:encryptedFabricTestToken -Key $script:fabricTestTokenKey }
        }
        Mock -ModuleName Maester Invoke-RestMethod { [pscustomobject]@{} }

        @(InModuleScope Maester { Get-MtFabricTenantSettings }) | Should -HaveCount 0
    }

    It 'caches tenant settings for the current Maester run' {
        Mock -ModuleName Maester Get-AzAccessToken {
            [pscustomobject]@{ Token = ConvertTo-SecureString -String $script:encryptedFabricTestToken -Key $script:fabricTestTokenKey }
        }
        Mock -ModuleName Maester Invoke-RestMethod {
            [pscustomobject]@{ value = @([pscustomobject]@{ settingName = 'FirstSetting'; enabled = $true }); continuationUri = $null }
        }

        InModuleScope Maester {
            Get-MtFabricTenantSettings | Out-Null
            Get-MtFabricTenantSettings | Out-Null
        }

        Should -Invoke Invoke-RestMethod -ModuleName Maester -Exactly -Times 1
        Should -Invoke Get-AzAccessToken -ModuleName Maester -Exactly -Times 1
    }

    It 'propagates errors from the Fabric admin API' {
        Mock -ModuleName Maester Get-AzAccessToken {
            [pscustomobject]@{ Token = ConvertTo-SecureString -String $script:encryptedFabricTestToken -Key $script:fabricTestTokenKey }
        }
        Mock -ModuleName Maester Invoke-RestMethod { throw 'Fabric settings request failed.' }

        { InModuleScope Maester { Get-MtFabricTenantSettings } } | Should -Throw '*Fabric settings request failed.*'
    }
}

Describe 'Test-MtCisFabricTenantSetting' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It 'throws when the setting is missing, duplicated, or has a non-Boolean enabled state' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings { @() }
        {
            InModuleScope Maester {
                Test-MtCisFabricTenantSetting -SettingName 'MissingSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
            }
        } | Should -Throw '*received 0*'

        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @(
                [pscustomobject]@{ settingName = 'TestSetting'; enabled = $false }
                [pscustomobject]@{ settingName = 'TestSetting'; enabled = $false }
            )
        }
        {
            InModuleScope Maester {
                Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
            }
        } | Should -Throw '*received 2*'

        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $null })
        }
        {
            InModuleScope Maester {
                Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
            }
        } | Should -Throw '*Boolean enabled value*'
    }

    It 'passes a disabled setting without requiring a security group' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $false })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
        }

        $result | Should -BeTrue
    }

    It 'requires at least one security group when a restricted setting is enabled' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $true })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
        }

        $result | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Result -like '*Disable it or restrict it to one or more security groups.*' -and $Result -like '*| Test setting | True | Entire organization | Not applicable | Fail |*'
        }
    }

    It 'passes an enabled setting without requiring a security group' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $true })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule Enabled
        }

        $result | Should -BeTrue
    }

    It 'requires Publish to web to be group-scoped and allow only existing embed codes' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{
                    settingName           = 'PublishToWeb'
                    enabled               = $true
                    enabledSecurityGroups = @('group-id')
                    properties            = @(
                        [pscustomobject]@{ name = 'AnotherSetting'; value = 'true' }
                        [pscustomobject]@{ name = 'CreateP2w'; value = 'false' }
                    )
                })
        }

        $passingResult = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $passingResult | Should -BeTrue

        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{
                    settingName           = 'PublishToWeb'
                    enabled               = $true
                    enabledSecurityGroups = @('group-id')
                    properties            = @([pscustomobject]@{ name = 'CreateP2w'; value = 'true' })
                })
        }

        $newCodesResult = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $newCodesResult | Should -BeFalse

        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{
                    settingName           = 'PublishToWeb'
                    enabled               = $true
                    enabledSecurityGroups = @('group-id')
                    properties            = @([pscustomobject]@{ name = 'CreateP2w'; value = 'not-a-boolean' })
                })
        }

        $invalidPropertyResult = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $invalidPropertyResult | Should -BeFalse
    }

    It 'passes an enabled restricted setting when its security group list is not empty' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $true; enabledSecurityGroups = @('group-id') })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule DisabledOrGroups
        }

        $result | Should -BeTrue
    }

    It 'passes the Disabled rule only when the setting is disabled' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $false })
        }

        $disabledResult = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule Disabled
        }

        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $true })
        }

        $enabledResult = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule Disabled
        }

        $disabledResult | Should -BeTrue
        $enabledResult | Should -BeFalse
    }

    It 'fails the Enabled rule when the setting is disabled' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'TestSetting'; enabled = $false })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'TestSetting' -SettingTitle 'Test setting' -Rule Enabled
        }

        $result | Should -BeFalse
    }

    It 'passes disabled Publish to web without asserting its nested configuration' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{ settingName = 'PublishToWeb'; enabled = $false })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $result | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
            $Result -like '*Well done. Publish to web is disabled.*' -and $Result -like '*| Publish to web | False | Not applicable | Not applicable | Pass |*' -and $Result -notlike '*only existing embed codes allowed*'
        }
    }

    It 'fails Publish to web when existing-code mode is enabled without a security group' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{
                    settingName           = 'PublishToWeb'
                    enabled               = $true
                    enabledSecurityGroups = @()
                    properties            = @([pscustomobject]@{ name = 'CreateP2w'; value = 'false' })
                })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $result | Should -BeFalse
    }

    It 'fails Publish to web when the nested createP2w property is absent' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            @([pscustomobject]@{
                    settingName           = 'PublishToWeb'
                    enabled               = $true
                    enabledSecurityGroups = @('group-id')
                })
        }

        $result = InModuleScope Maester {
            Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
        }

        $result | Should -BeFalse
    }
}
