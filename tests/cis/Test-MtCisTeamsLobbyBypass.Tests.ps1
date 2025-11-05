Describe "CIS" -Tag "CIS.M365.8.5.3", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.8.5.3: (L1) Ensure only people in my org can bypass the lobby" {

        $result = Test-MtCisTeamsLobbyBypass

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Global (Org-wide default) meeting policy is configured to only bypass the lobby for 'Peoply in my org'."
        }
    }
}
