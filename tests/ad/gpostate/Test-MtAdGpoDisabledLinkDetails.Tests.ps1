Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-13" {
    It "AD-GPOREP-13: GPO disabled link details should be investigated" {
        $result = Test-MtAdGpoDisabledLinkDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
