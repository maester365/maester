Describe "Active Directory - Group Policy" -Tag "AD", "AD.GPO", "AD-GPOL-01" {
    It "AD-GPOL-01: GPO linked count should be investigated" {

        $result = Test-MtAdGpoLinkedCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO linked data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
