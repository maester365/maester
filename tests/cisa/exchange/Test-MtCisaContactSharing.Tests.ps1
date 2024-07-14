Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.6.1", "CISA", "Security", "All" {
    It "MS.EXO.6.1: Contact folders SHALL NOT be shared with all domains." {

        $cisaContactSharing = Test-MtCisaContactSharing

        if($null -ne $cisaContactSharing) {
            $cisaContactSharing | Should -Be $true -Because "contact sharing is disabled."
        }
    }
}