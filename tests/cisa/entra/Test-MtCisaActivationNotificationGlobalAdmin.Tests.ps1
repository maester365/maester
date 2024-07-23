Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.8", "CISA", "Security", "All" {
    It "MS.AAD.7.8: User activation of the Global Administrator role SHALL trigger an alert." {
        $result = Test-MtCisaActivationNotification -GlobalAdminOnly

        if ($null -ne $result) {
            $result | Should -Be $true -Because "notifications are set for activation of the Global Admin role."
        }
    }
}