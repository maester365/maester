Describe "Active Directory - Password Policy" -Tag "AD", "AD.PasswordPolicy", "AD-FGPP-03" {
    It "AD-FGPP-03: Fine-grained password policy setting counts should be retrievable" {

        $result = Test-MtAdFineGrainedPolicySettingCounts

        if ($null -ne $result) {
            $result | Should -Be $true -Because "fine-grained password policy data should be accessible"
        }
    }
}
