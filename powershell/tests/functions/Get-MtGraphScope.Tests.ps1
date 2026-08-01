Describe 'Get-MtGraphScope' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    It 'Includes EntitlementManagement.Read.All in default scopes' {
        $scopes = Get-MtGraphScope

        $scopes | Should -Contain 'EntitlementManagement.Read.All'
    }

    It 'Keeps EntitlementManagement.Read.All in sorted position between DirectoryRecommendations and IdentityRiskEvent' {
        $scopes = Get-MtGraphScope
        $directoryRecommendationsIndex = [array]::IndexOf($scopes, 'DirectoryRecommendations.Read.All')
        $entitlementManagementIndex = [array]::IndexOf($scopes, 'EntitlementManagement.Read.All')
        $identityRiskEventIndex = [array]::IndexOf($scopes, 'IdentityRiskEvent.Read.All')

        $directoryRecommendationsIndex | Should -BeLessThan $entitlementManagementIndex
        $entitlementManagementIndex | Should -BeLessThan $identityRiskEventIndex
    }

    It 'Includes the PIM v3 role management alert scope and excludes the deprecated PIM v2 scope' {
        $scopes = Get-MtGraphScope

        $scopes | Should -Contain 'RoleManagementAlert.Read.Directory'
        $scopes | Should -Not -Contain 'PrivilegedAccess.Read.AzureAD'
    }

    It 'Keeps RoleManagementAlert.Read.Directory in sorted position between RoleManagement and SecurityIdentitiesSensors' {
        $scopes = Get-MtGraphScope
        $roleManagementIndex = [array]::IndexOf($scopes, 'RoleManagement.Read.All')
        $roleManagementAlertIndex = [array]::IndexOf($scopes, 'RoleManagementAlert.Read.Directory')
        $securityIdentitiesSensorsIndex = [array]::IndexOf($scopes, 'SecurityIdentitiesSensors.Read.All')

        $roleManagementIndex | Should -BeLessThan $roleManagementAlertIndex
        $roleManagementAlertIndex | Should -BeLessThan $securityIdentitiesSensorsIndex
    }
}
