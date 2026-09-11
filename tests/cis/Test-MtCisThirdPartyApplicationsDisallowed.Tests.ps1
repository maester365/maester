Describe "CIS" -Tag "CIS.M365.5.1.2.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v7.0.0" {
    It "CIS.M365.5.1.2.2: Ensure users cannot register applications" {

        $result = Test-MtCisThirdPartyApplicationsDisallowed

        if ($null -ne $result) {
            $result | Should -Be $true -Because "users are not allowed to register third party applications in the tenant."
        }
    }
}
