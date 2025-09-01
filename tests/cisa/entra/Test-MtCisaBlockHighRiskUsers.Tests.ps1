Describe "CISA" -Tag "MS.AAD", "MS.AAD.2.1", "CISA.MS.AAD.2.1", "CISA", "Security", "Entra ID P2"{
    It "CISA.MS.AAD.2.1: Users detected as high risk SHALL be blocked." {
        $result = Test-MtCisaBlockHighRiskUser

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled policy for all users blocking high risk users shall exist."
        }
    }
}
