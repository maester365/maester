Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.8.1", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.8.1: Guest users SHOULD have limited or restricted access to Azure AD directory objects." {
        $result = Test-MtCisaGuestUserAccess

        if ($null -ne $result) {
            $result | Should -Be $true -Because "guest users have appropriate role."
        }
    }
}