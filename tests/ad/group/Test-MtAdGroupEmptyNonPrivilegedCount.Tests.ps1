Describe "Active Directory - Group Members" -Tag "AD", "AD.Group", "AD.GMC", "AD-GMC-08" {
    It "AD-GMC-08: Empty non-privileged group count should be investigated" {

        $result = Test-MtAdGroupEmptyNonPrivilegedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "empty non-privileged group data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
