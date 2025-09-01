Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.9", "CISA.MS.AAD.7.9", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.9: User activation of other highly privileged roles SHOULD trigger an alert." {
        $result = Test-MtCisaActivationNotification

        if ($null -ne $result) {
            $result | Should -Be $true -Because "notifications are set for activation of highly privileged roles."
        }
    }
}
