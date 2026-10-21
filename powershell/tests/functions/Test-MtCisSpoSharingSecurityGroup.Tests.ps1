Describe 'Test-MtCisSpoSharingSecurityGroup' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisSpoSharingSecurityGroup
    }

    BeforeEach {
        $script:SpoTenant = $null
        Mock -ModuleName Maester Get-MtSpo { $script:SpoTenant }
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It 'fails when only the anonymous-sharing allow-list is configured' {
        $script:SpoTenant = [pscustomobject]@{
            SharingCapability = 'ExternalUserAndGuestSharing'
            WhoCanShareAuthenticatedGuestAllowList = @()
            WhoCanShareAnonymousAllowList = @('anonymous-group')
            GuestSharingGroupAllowListInTenantByPrincipalIdentity = @()
        }

        Test-MtCisSpoSharingSecurityGroup | Should -BeFalse
    }

    It 'passes when the authenticated-guest allow-list contains a group' {
        $script:SpoTenant = [pscustomobject]@{
            SharingCapability = 'ExternalUserAndGuestSharing'
            WhoCanShareAuthenticatedGuestAllowList = @('authenticated-group')
            WhoCanShareAnonymousAllowList = @()
            GuestSharingGroupAllowListInTenantByPrincipalIdentity = @()
        }

        Test-MtCisSpoSharingSecurityGroup | Should -BeTrue
    }

    It 'passes when external sharing is disabled' {
        $script:SpoTenant = [pscustomobject]@{
            SharingCapability = 'Disabled'
            WhoCanShareAuthenticatedGuestAllowList = @()
            WhoCanShareAnonymousAllowList = @()
            GuestSharingGroupAllowListInTenantByPrincipalIdentity = @()
        }

        Test-MtCisSpoSharingSecurityGroup | Should -BeTrue
    }
}
