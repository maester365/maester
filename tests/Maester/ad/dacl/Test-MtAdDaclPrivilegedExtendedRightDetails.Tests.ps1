Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-12" {
    It "AD-DACL-12: Privileged extended right details should be retrievable" {
        $result = Test-MtAdDaclPrivilegedExtendedRightDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged extended right detail data should be accessible"
        }
    }
}
