Describe "CISA ScubaGear MS.AAD.2.1v1 & MS.AAD.2.3v1" -Tag "CISA", "Security", "All" {
    It "MS.AAD.2.1v1: Users detected as high risk SHALL be blocked. & MS.AAD.2.1v1: Sign-ins detected as high risk SHALL be blocked." {
        Test-MtCisaBlockHighRisk | Should -Be $true -Because "an enabled policy for all users blocking high risk logins shall exist."
    }
}