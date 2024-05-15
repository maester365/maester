Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.8.1", "CISA", "Security", "All" {
    It "MS.AAD.8.1: Guest users SHOULD have limited or restricted access to Azure AD directory objects." {
        Test-MtCisaGuestUserAccess | Should -Be $true -Because "guest users have appropriate role."
    }
}