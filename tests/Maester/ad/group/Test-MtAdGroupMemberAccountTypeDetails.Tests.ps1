Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD-GMC-03" {
    It "AD-GMC-03: Member account types breakdown should be retrievable" {

        $result = Test-MtAdGroupMemberAccountTypeDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "account type details should be accessible"
        }
    }
}
