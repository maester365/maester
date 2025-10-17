Describe "CISA" -Tag "MS.AAD", "MS.AAD.5.4", "CISA.MS.AAD.5.4", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.5.4: Group owners SHALL NOT be allowed to consent to applications." {
        $result = Test-MtCisaAppGroupOwnerConsent

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group owner consent is disabled."
        }
    }
}
