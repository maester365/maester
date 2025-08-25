Describe "CISA" -Tag "MS.AAD", "MS.AAD.6.1", "CISA.MS.AAD.6.1", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.6.1: User passwords SHALL NOT expire." {
        $result = Test-MtCisaPasswordExpiration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "at least 1 domain has an password expiration policy of 100 years or more."
        }
    }
}
