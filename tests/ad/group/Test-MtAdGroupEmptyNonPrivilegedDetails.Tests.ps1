Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-09" {
    It "AD-GMC-09: Empty non-privileged group details should be retrievable" {

        $result = Test-MtAdGroupEmptyNonPrivilegedDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "empty non-privileged group details should be accessible"
        }
    }
}
