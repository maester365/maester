Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.8", "CISA.MS.AAD.7.8", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert." {
        $result = Test-MtCisaActivationNotification -GlobalAdminOnly

        if ($null -ne $result) {
            $result | Should -Be $true -Because "notifications are set for activation of the Global Admin role."
        }
    }
}
