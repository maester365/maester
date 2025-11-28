Describe "CISA" -Tag "MS.AAD", "MS.AAD.8.2", "CISA.MS.AAD.8.2", "CISA", "Security", "Entra ID Free" {
    It "CISA.MS.AAD.8.2: Only users with the Guest Inviter role SHOULD be able to invite guest users." {
        $result = Test-MtCisaGuestInvitation

        if ($null -ne $result) {
            $result | Should -Be $true -Because "guest invitations are restricted to admins."
        }
    }
}
