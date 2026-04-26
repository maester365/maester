Describe "Active Directory - Forest" -Tag "AD", "AD.Forest", "AD-FOR-04" {
    It "AD-FOR-04: Recycle Bin status should be retrievable" {

        $result = Test-MtAdRecycleBinStatus

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Recycle Bin status data should be accessible"
        }
    }
}
