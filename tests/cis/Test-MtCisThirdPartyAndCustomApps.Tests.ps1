Describe "CIS" -Tag "Security", "CIS", "CIS M365 v5.0.0" {
    It "CIS.M365.8.4.1: (L1) Ensure all or a majority of third-party and custom apps are blocked" -Tag "CIS.M365.8.4.1", "CIS E3 Level 1" {

        $result = Test-MtCisThirdPartyAndCustomApps

        if ($null -ne $result) {
            $result | Should -Be $true -Because "all or a majority of third-party and custom apps are blocked."
        }
    }
}
