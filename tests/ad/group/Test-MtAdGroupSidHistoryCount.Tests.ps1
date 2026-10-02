Describe "Active Directory - Groups" -Tag "AD", "AD.Group", "AD-GRP-05" {
    It "AD-GRP-05: Group SID History count should be retrievable" {

        $result = Test-MtAdGroupSidHistoryCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "group data should be accessible"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
