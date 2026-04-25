Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-05" {
    It "AD-COMP-05: Computer SID History count should be retrievable" {

        $result = Test-MtAdComputerSidHistoryCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SID History data should be accessible"
        }
    }
}
