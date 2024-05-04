Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.5.3", "CISA", "Security", "All" {
    It "MS.AAD.5.3: An admin consent workflow SHALL be configured for applications." {
        Test-MtCisaAppAdminConsent | Should -Be $true -Because "admin consent policy is configured with reviewers."
    }
}