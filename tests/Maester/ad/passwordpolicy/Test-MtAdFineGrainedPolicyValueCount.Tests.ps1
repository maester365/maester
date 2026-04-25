Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-FGPP-02" {
    It "AD-FGPP-02: Fine-grained password policy value count should be retrievable" {

        $result = Test-MtAdFineGrainedPolicyValueCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "fine-grained password policy data should be accessible"
        }
    }
}
