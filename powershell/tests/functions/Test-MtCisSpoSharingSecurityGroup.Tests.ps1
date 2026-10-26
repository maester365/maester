Describe 'Test-MtCisSpoSharingSecurityGroup' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSpoSharingSecurityGroup

        function New-TestSpoTenant {
            param(
                [string] $SharingCapability = 'ExternalUserAndGuestSharing',
                [string[]] $Authenticated = @(),
                [string[]] $Anonymous = @()
            )
            [pscustomobject]@{
                SharingCapability                                     = $SharingCapability
                WhoCanShareAuthenticatedGuestAllowList                = $Authenticated
                WhoCanShareAnonymousAllowList                         = $Anonymous
                GuestSharingGroupAllowListInTenantByPrincipalIdentity = @()
            }
        }
    }

    BeforeEach {
        $script:SpoTenant = $null
        $script:TestResult = $null
        Mock -ModuleName Maester Get-MtSpo { $script:SpoTenant }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:TestResult = $Result }
    }

    It 'fails when only the anonymous-sharing allow-list is configured' {
        $script:SpoTenant = New-TestSpoTenant -Anonymous 'anonymous-group'

        Test-MtCisSpoSharingSecurityGroup | Should -BeFalse
        $script:TestResult | Should -Match 'every group can share with Anyone'
        $script:TestResult | Should -Match '\| WhoCanShareAuthenticatedGuestAllowList \| Not set \| Fail \|'
    }

    It 'passes when the authenticated-guest allow-list contains a group' {
        $script:SpoTenant = New-TestSpoTenant -Authenticated 'authenticated-group'

        Test-MtCisSpoSharingSecurityGroup | Should -BeTrue
    }

    It 'passes when both allow-lists contain a group' {
        $script:SpoTenant = New-TestSpoTenant -Authenticated 'authenticated-group' -Anonymous 'anonymous-group'

        Test-MtCisSpoSharingSecurityGroup | Should -BeTrue
    }

    It 'fails when no group is configured' {
        $script:SpoTenant = New-TestSpoTenant

        Test-MtCisSpoSharingSecurityGroup | Should -BeFalse
        $script:TestResult | Should -Match 'not limited to members of a security group'
    }

    It 'passes when external sharing is disabled' {
        $script:SpoTenant = New-TestSpoTenant -SharingCapability 'Disabled'

        Test-MtCisSpoSharingSecurityGroup | Should -BeTrue
        $script:TestResult | Should -Match '\| WhoCanShareAuthenticatedGuestAllowList \| Not set \| Not required \|'
    }
}
