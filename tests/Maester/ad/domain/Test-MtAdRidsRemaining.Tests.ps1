Describe "Active Directory - Domain" -Tag "AD", "AD.Domain", "AD-DOM-04" {
    It "AD-DOM-04: RIDs remaining should be retrievable" {

        $result = Test-MtAdRidsRemaining

        if ($null -ne $result) {
            $result | Should -Be $true -Because "RID pool data should be accessible"
        }
    }
}
