Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.9", "CISA", "Security", "All", "Entra ID P2" {
    It "MS.AAD.7.9: User activation of other highly privileged roles SHOULD trigger an alert." {
        $result = Test-MtCisaActivationNotification

        if ($null -ne $result) {
            $result | Should -Be $true -Because "notifications are set for activation of highly privileged roles."
        }
    }
}