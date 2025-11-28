Describe "CISA" -Tag "MS.AAD", "MS.AAD.2.2", "CISA.MS.AAD.2.2", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.2.2: A notification SHOULD be sent to the administrator when high-risk users are detected." {
        $result = Test-MtCisaNotifyHighRisk

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled is a recipient of risky user login notifications."
        }
    }
}
