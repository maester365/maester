Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.5.2", "CISA", "Security", "All" {
    It "MS.AAD.5.2: Only administrators SHALL be allowed to consent to applications." {
        Test-MtCisaAppUserConsent | Should -Be $true -Because "default user authorization policy prevents app consent."
    }
}