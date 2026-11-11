BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:createdTeamsStubs = @()
    $teamsStubs = @{
        'Get-CsTeamsMeetingPolicy' = {
            [CmdletBinding()]
            param([string]$Identity)
            $null = $PSBoundParameters
        }
        'Get-CsTeamsAppPermissionPolicy' = {
            [CmdletBinding()]
            param([string]$Identity)
            $null = $PSBoundParameters
        }
        'Get-CsTenantFederationConfiguration' = {
            [CmdletBinding()]
            param()
        }
        'Get-CsTeamsMeetingBroadcastPolicy' = {
            [CmdletBinding()]
            param([string]$Identity)
            $null = $PSBoundParameters
        }
        'Get-CsTeamsClientConfiguration' = {
            [CmdletBinding()]
            param([string]$Identity)
            $null = $PSBoundParameters
        }
    }
    foreach ($name in $teamsStubs.Keys) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            Set-Item -Path "Function:global:$name" -Value $teamsStubs[$name]
            $script:createdTeamsStubs += $name
        }
    }
}

AfterAll {
    foreach ($name in $script:createdTeamsStubs) {
        Remove-Item -Path "Function:global:$name" -ErrorAction SilentlyContinue
    }
}

Describe 'CISA Teams checks' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.TeamsCache = @{}
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {}
    }

    It 'Checks every meeting policy for a Boolean setting' {
        Mock Get-CsTeamsMeetingPolicy -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowAnonymousUsersToStartMeeting = $false }
                [pscustomobject]@{ Identity = 'Custom'; AllowAnonymousUsersToStartMeeting = $false }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsMeetingPolicyBoolean -SettingName AllowAnonymousUsersToStartMeeting -ExpectedValue $false -PolicyDescription 'Anonymous meeting start' | Should -BeTrue
        }
        Should -Invoke Get-CsTeamsMeetingPolicy -ModuleName Maester -Times 1 -Exactly
    }

    It 'Fails a meeting policy when the setting differs from the baseline' {
        Mock Get-CsTeamsMeetingPolicy -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowAnonymousUsersToStartMeeting = $false }
                [pscustomobject]@{ Identity = 'Custom'; AllowAnonymousUsersToStartMeeting = $true }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsMeetingPolicyBoolean -SettingName AllowAnonymousUsersToStartMeeting -ExpectedValue $false -PolicyDescription 'Anonymous meeting start' | Should -BeFalse
        }
    }

    It 'Errors when a meeting policy does not return the checked setting' {
        Mock Get-CsTeamsMeetingPolicy -ModuleName Maester {
            [pscustomobject]@{ Identity = 'Global' }
        }

        { InModuleScope Maester { Test-MtCisaTeamsMeetingPolicyBoolean -SettingName AllowAnonymousUsersToStartMeeting -ExpectedValue $false -PolicyDescription 'Anonymous meeting start' } } | Should -Throw '*did not return a Boolean value*'
    }

    It 'Passes external federation when disabled' {
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            [pscustomobject]@{ AllowFederatedUsers = $false }
        }

        InModuleScope Maester {
            Test-MtCisaTeamsExternalAccessScope | Should -BeTrue
        }
    }

    It 'Fails external federation when all known domains are allowed' {
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            $domains = [pscustomobject]@{}
            $domains.PSObject.TypeNames.Insert(0, 'AllowAllKnownDomains')
            [pscustomobject]@{
                AllowFederatedUsers = $true
                AllowedDomains      = $domains
            }
        }

        InModuleScope Maester {
            Test-MtCisaTeamsExternalAccessScope | Should -BeFalse
        }
    }

    It 'Passes external federation when only configured domains are allowed' {
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            [pscustomobject]@{
                AllowFederatedUsers = $true
                AllowedDomains      = [pscustomobject]@{ AllowedDomain = @('contoso.com') }
            }
        }

        InModuleScope Maester {
            Test-MtCisaTeamsExternalAccessScope | Should -BeTrue
        }
    }

    It 'Fails external federation when any configuration allows all domains' {
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            $domains = [pscustomobject]@{}
            $domains.PSObject.TypeNames.Insert(0, 'AllowAllKnownDomains')
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowFederatedUsers = $false }
                [pscustomobject]@{ Identity = 'Tag:Custom'; AllowFederatedUsers = $true; AllowedDomains = $domains }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsExternalAccessScope | Should -BeFalse
        }
    }

    It 'Fails unmanaged inbound contact when any configuration allows it' {
        Mock Test-MtCisaTeamsIsUSGovernment -ModuleName Maester { $false }
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowTeamsConsumerInbound = $false; AllowTeamsConsumer = $true }
                [pscustomobject]@{ Identity = 'Tag:Custom'; AllowTeamsConsumerInbound = $true; AllowTeamsConsumer = $true }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsUnmanagedInboundContact | Should -BeFalse
        }
    }

    It 'Passes unmanaged inbound contact when every configuration blocks inbound contact' {
        Mock Test-MtCisaTeamsIsUSGovernment -ModuleName Maester { $false }
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowTeamsConsumerInbound = $false; AllowTeamsConsumer = $true }
                [pscustomobject]@{ Identity = 'Tag:Custom'; AllowTeamsConsumerInbound = $true; AllowTeamsConsumer = $false }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsUnmanagedInboundContact | Should -BeTrue
        }
    }

    It 'Fails unmanaged outbound contact when any configuration allows it' {
        Mock Test-MtCisaTeamsIsUSGovernment -ModuleName Maester { $false }
        Mock Get-MtCisaTeamsFederationConfigurations -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; AllowTeamsConsumer = $false }
                [pscustomobject]@{ Identity = 'Tag:Custom'; AllowTeamsConsumer = $true }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsUnmanagedOutboundContact | Should -BeFalse
        }
    }

    It 'Uses an available unified org-wide app setting instead of legacy policies' {
        Mock Get-MtTeamsUnifiedTenantSettings -ModuleName Maester {
            @([pscustomobject]@{ SettingName = 'GlobalApp'; SettingValue = 'None' })
        }
        Mock Get-CsTeamsAppPermissionPolicy -ModuleName Maester { throw 'Legacy policies should not be queried.' }

        InModuleScope Maester {
            Test-MtCisaTeamsAppControl -SettingName GlobalApp -AppType Third-party | Should -BeTrue
        }
        Should -Invoke Get-CsTeamsAppPermissionPolicy -ModuleName Maester -Times 0 -Exactly
    }

    It 'Fails an available unified org-wide app setting that is not None' {
        Mock Get-MtTeamsUnifiedTenantSettings -ModuleName Maester {
            @([pscustomobject]@{ SettingName = 'PrivateApp'; SettingValue = 'All' })
        }
        Mock Get-CsTeamsAppPermissionPolicy -ModuleName Maester { throw 'Legacy policies should not be queried.' }

        InModuleScope Maester {
            Test-MtCisaTeamsAppControl -SettingName PrivateApp -AppType Custom | Should -BeFalse
        }
        Should -Invoke Get-CsTeamsAppPermissionPolicy -ModuleName Maester -Times 0 -Exactly
    }

    It 'Falls back to all legacy app permission policies when the unified setting is unavailable' {
        Mock Get-MtTeamsUnifiedTenantSettings -ModuleName Maester { $null }
        Mock Get-CsTeamsAppPermissionPolicy -ModuleName Maester {
            @(
                [pscustomobject]@{ Identity = 'Global'; DefaultCatalogAppsType = 'AllowedAppList' }
                [pscustomobject]@{ Identity = 'Custom'; DefaultCatalogAppsType = 'BlockedAppList' }
            )
        }

        InModuleScope Maester {
            Test-MtCisaTeamsAppControl -SettingName DefaultApp -AppType Microsoft | Should -BeFalse
        }
        Should -Invoke Get-CsTeamsAppPermissionPolicy -ModuleName Maester -Times 1 -Exactly
    }
}
