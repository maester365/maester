Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-FGPP-01" {
    It "AD-FGPP-01: Fine-grained password policy count should be retrievable" {

        $result = Test-MtAdFineGrainedPolicyCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "fine-grained password policy data should be accessible"
        }
    }
}
