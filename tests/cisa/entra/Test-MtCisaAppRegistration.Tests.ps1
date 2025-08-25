Describe "CISA" -Tag "MS.AAD", "MS.AAD.5.1", "CISA.MS.AAD.5.1", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.5.1: Only administrators SHALL be allowed to register applications." {
        $result = Test-MtCisaAppRegistration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default user authorization policy prevents app creation."
        }
    }
}
