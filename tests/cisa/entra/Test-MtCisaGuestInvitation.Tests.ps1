Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.8.2", "CISA", "Security", "All", "Entra ID Free" {
    It "MS.AAD.8.2: Only users with the Guest Inviter role SHOULD be able to invite guest users." {
        $result = Test-MtCisaGuestInvitation

        if ($null -ne $result) {
            $result | Should -Be $true -Because "guest invitations are restricted to admins."
        }
    }
}