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
        $directoryRecommendationsIndex = $scopes.IndexOf('DirectoryRecommendations.Read.All')
        $entitlementManagementIndex = $scopes.IndexOf('EntitlementManagement.Read.All')
        $identityRiskEventIndex = $scopes.IndexOf('IdentityRiskEvent.Read.All')

        $directoryRecommendationsIndex | Should -BeLessThan $entitlementManagementIndex
        $entitlementManagementIndex | Should -BeLessThan $identityRiskEventIndex
    }
}
