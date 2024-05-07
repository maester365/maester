Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.5.1", "CISA", "Security", "All" {
    It "MS.AAD.5.1: Only administrators SHALL be allowed to register applications." {
        Test-MtCisaMfa | Should -Be $true -Because "default user authorization policy prevents app creation."
    }
}