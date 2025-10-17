Describe "CISA" -Tag "MS.AAD", "MS.AAD.7.6", "CISA.MS.AAD.7.6", "CISA", "Security", "Entra ID P2" {
    It "CISA.MS.AAD.7.6: Activation of the Global Administrator role SHALL require approval." {
        $result = Test-MtCisaRequireActivationApproval

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Global Administrator role requires approval for activation."
        }
    }
}
