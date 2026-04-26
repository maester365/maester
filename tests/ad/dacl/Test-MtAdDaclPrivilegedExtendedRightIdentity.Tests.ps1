Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-13" {
    It "AD-DACL-13: Privileged extended right identities should be retrievable" {
        $result = Test-MtAdDaclPrivilegedExtendedRightIdentity
        if ($null -ne $result) {
            $result | Should -Be $true -Because "DACL data should be accessible"
        }
    }
}
