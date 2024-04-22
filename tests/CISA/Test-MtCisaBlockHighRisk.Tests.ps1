Describe "CISA ScubaGear MS.AAD.1.1v1" -Tag "CISA", "Security", "All" {
    It "MS.AAD.1.1v1: Legacy authentication SHALL be blocked." {
        Test-MtCisaLegacyAuth | Should -Be $true -Because "an enabled policy for all users blocking legacy auth access shall exist."
    }
}