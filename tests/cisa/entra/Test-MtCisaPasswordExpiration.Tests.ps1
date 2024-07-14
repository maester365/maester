Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.6.1", "CISA", "Security", "All" {
    It "MS.AAD.6.1: User passwords SHALL NOT expire." {
        Test-MtCisaPasswordExpiration | Should -Be $true -Because "at least 1 domain has an password expiration policy of 100 years or more."
    }
}