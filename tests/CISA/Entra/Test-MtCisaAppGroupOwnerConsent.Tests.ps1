Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.5.4", "CISA", "Security", "All" {
    It "MS.AAD.5.4: Group owners SHALL NOT be allowed to consent to applications." {
        Test-MtCisaAppGroupOwnerConsent | Should -Be $true -Because "group owner consent is disabled."
    }
}