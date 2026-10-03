Describe "Active Directory - DACL" -Tag "AD", "AD.DACL", "AD-DACL-11" {
    It "AD-DACL-11: Privileged extended right count should be investigated" {
        $result = Test-MtAdDaclPrivilegedExtendedRightCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "privileged extended right count data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
