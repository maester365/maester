Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.5.2", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.5.2: Only administrators SHALL be allowed to consent to applications." {
        $result = Test-MtCisaAppUserConsent

        if ($null -ne $result) {
            $result | Should -Be $true -Because "default user authorization policy prevents app consent."
        }
    }
}