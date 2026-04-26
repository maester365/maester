Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-11" {
    It "AD-DACL-11: Privileged extended right count should be retrievable" {
        $result = Test-MtAdDaclPrivilegedExtendedRightCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged extended right count data should be accessible"
        }
    }
}
