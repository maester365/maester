BeforeDiscovery {
    $powerBiChecks = @(
        @{ Check = 'Test-MtCisaPowerBiPublishToWebDisabled'; Setting = 'PublishToWeb'; Enabled = $false; GroupScoped = $false }
        @{ Check = 'Test-MtCisaPowerBiGuestAccessRestricted'; Setting = 'AllowGuestUserToAccessSharedContent'; Enabled = $false; GroupScoped = $true }
        @{ Check = 'Test-MtCisaPowerBiGuestInvitationsRestricted'; Setting = 'ExternalSharingV2'; Enabled = $false; GroupScoped = $true }
        @{ Check = 'Test-MtCisaPowerBiServicePrincipalApisRestricted'; Setting = 'ServicePrincipalAccessPermissionAPIs'; Enabled = $false; GroupScoped = $true }
        @{ Check = 'Test-MtCisaPowerBiServicePrincipalProfilesRestricted'; Setting = 'AllowServicePrincipalsCreateAndUseProfiles'; Enabled = $false; GroupScoped = $true }
        @{ Check = 'Test-MtCisaPowerBiResourceKeyAuthenticationBlocked'; Setting = 'BlockResourceKeyAuthentication'; Enabled = $true; GroupScoped = $false }
        @{ Check = 'Test-MtCisaPowerBiScriptVisualsDisabled'; Setting = 'RScriptVisual'; Enabled = $false; GroupScoped = $false }
        @{ Check = 'Test-MtCisaPowerBiSensitivityLabels'; Setting = 'EimInformationProtectionEdit'; Enabled = $true; GroupScoped = $false }
    )
}

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
}

Describe 'CISA Power BI baseline: <Check>' -ForEach $powerBiChecks {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It 'accepts the audited enabled state, but requires investigation for actual label use' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = $Setting; enabled = $Enabled }
        }

        $result = @(InModuleScope Maester -Parameters @{ Check = $Check } {
                param($Check)
                & $Check
            })

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType [bool]
        $result[0] | Should -Be ($Setting -ne 'EimInformationProtectionEdit')
        if ($Setting -eq 'EimInformationProtectionEdit') {
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $Investigate -and $Result -match 'published' -and $Result -match 'sensitive'
            }
        }
        else {
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                -not $Investigate -and $Result -like 'Well done.*'
            }
        }
    }

    It 'fails the opposite enabled state without a security-group scope' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = $Setting; enabled = -not $Enabled; enabledSecurityGroups = @() }
        }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            & $Check | Should -BeFalse
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 0 -ParameterFilter { $Investigate }
    }

    It 'does not substitute an unrelated setting when the audited setting is missing' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = 'UnrelatedSetting'; enabled = $Enabled }
        }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*Expected exactly one Fabric tenant setting*'
        }
    }

    It 'errors on empty tenant settings' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings { @() }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*received 0*'
        }
    }

    It 'errors on duplicate audited settings' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = $Setting; enabled = $Enabled }
            [pscustomobject]@{ settingName = $Setting; enabled = -not $Enabled }
        }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*received 2*'
        }
    }

    It 'errors when enabled is absent rather than coercing it to false' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = $Setting }
        }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*Boolean enabled value*'
        }
    }

    It 'errors when enabled is a string rather than a Boolean' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{ settingName = $Setting; enabled = 'false' }
        }

        InModuleScope Maester -Parameters @{ Check = $Check } {
            param($Check)
            { & $Check } | Should -Throw '*Boolean enabled value*'
        }
    }

    It 'accepts enabled group scope only where the audit permits it' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{
                settingName           = $Setting
                enabled               = $true
                enabledSecurityGroups = @([pscustomobject]@{ graphId = 'approved-group'; name = 'Approved applications or users' })
                properties            = @([pscustomobject]@{ name = 'CreateP2w'; value = 'false' })
            }
        }

        InModuleScope Maester -Parameters @{ Check = $Check; Expected = ($GroupScoped -or $Enabled) -and $Setting -ne 'EimInformationProtectionEdit' } {
            param($Check, $Expected)
            & $Check | Should -Be $Expected
        }
    }
}

Describe 'Power BI publish-to-web audit differs from CIS without changing CIS behavior' {
    BeforeEach {
        Mock -ModuleName Maester Add-MtTestResultDetail {}
        Mock -ModuleName Maester Get-MtFabricTenantSettings {
            [pscustomobject]@{
                settingName           = 'PublishToWeb'
                enabled               = $true
                enabledSecurityGroups = @([pscustomobject]@{ graphId = 'approved-group' })
                properties            = @([pscustomobject]@{ name = 'CreateP2w'; value = 'false' })
            }
        }
    }

    It 'keeps the CIS group-scoped existing-code exception but fails SCuBA' {
        InModuleScope Maester {
            Test-MtCisFabricPublishToWebRestricted | Should -BeTrue
            Test-MtCisaPowerBiPublishToWebDisabled | Should -BeFalse
        }
    }

    It 'propagates transport permission errors instead of reporting compliance' {
        Mock -ModuleName Maester Get-MtFabricTenantSettings { throw '403 Forbidden' }

        InModuleScope Maester {
            { Test-MtCisaPowerBiPublishToWebDisabled } | Should -Throw '*403 Forbidden*'
            { Test-MtCisaPowerBiSensitivityLabels } | Should -Throw '*403 Forbidden*'
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly -Times 0
    }
}
