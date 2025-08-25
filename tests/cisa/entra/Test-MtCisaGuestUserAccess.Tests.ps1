Describe "CISA" -Tag "MS.AAD", "MS.AAD.8.1", "CISA.MS.AAD.8.1", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.8.1: Guest users SHOULD have limited or restricted access to Entra ID directory objects." {
        $result = Test-MtCisaGuestUserAccess

        if ($null -ne $result) {
            $result | Should -Be $true -Because "guest users have appropriate role."
        }
    }
}
