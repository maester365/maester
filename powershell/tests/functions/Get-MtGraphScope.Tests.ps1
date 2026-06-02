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
}
