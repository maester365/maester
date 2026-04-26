Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-FGPP-04" {
    It "AD-FGPP-04: Fine-grained password policy application targets should be retrievable" {

        $result = Test-MtAdFineGrainedPolicyAppliesTo

        if ($null -ne $result) {
            $result | Should -Be $true -Because "fine-grained password policy data should be accessible"
        }
    }
}
