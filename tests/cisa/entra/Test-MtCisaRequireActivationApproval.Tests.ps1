Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.7.6", "CISA", "Security", "All", "Entra ID P2" {
    It "MS.AAD.7.6: Activation of the Global Administrator role SHALL require approval." {
        $result = Test-MtCisaRequireActivationApproval

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Global Administrator role requires approval for activation."
        }
    }
}