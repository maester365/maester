Describe "CIS" -Tag "All", "Security", "CIS", "CIS M365 v4.0.0" {
    It "CIS 8.4.1 (L1) Ensure all or a majority of third-party and custom apps are blocked" -Tag "CIS 8.4.1", "CIS E3 Level 1" {

        $result = Test-MtCisThirdPartyAndCustomApps

        if ($null -ne $result) {
            $result | Should -Be $true -Because "all or a majority of third-party and custom apps are blocked."
        }
    }
}