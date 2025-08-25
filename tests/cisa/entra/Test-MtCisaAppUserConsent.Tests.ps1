Describe "CISA" -Tag "MS.AAD", "MS.AAD.5.2", "CISA.MS.AAD.5.2", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.5.2: Only administrators SHALL be allowed to consent to applications." {
        $result = Test-MtCisaAppUserConsent

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default user authorization policy prevents app consent."
        }
    }
}
