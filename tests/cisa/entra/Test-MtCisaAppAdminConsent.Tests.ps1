Describe "CISA" -Tag "MS.AAD", "MS.AAD.5.3", "CISA.MS.AAD.5.3", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.5.3: An admin consent workflow SHALL be configured for applications." {
        $result = Test-MtCisaAppAdminConsent

        if ($null -ne $result) {
            $result | Should -Be $true -Because "admin consent policy is configured with reviewers."
        }
    }
}
