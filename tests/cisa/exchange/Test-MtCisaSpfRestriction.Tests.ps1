Describe "CISA" -Tag "MS.EXO", "MS.EXO.2.1", "CISA.MS.EXO.2.1", "CISA", "Security" {
    It "CISA.MS.EXO.2.1: A list of approved IP addresses for sending mail SHALL be maintained." {
        $cisaSpfRestriction = Test-MtCisaSpfRestriction

        if ($null -ne $cisaSpfRestriction) {
            $cisaSpfRestriction | Should -Be $true -Because "SPF record should restrict authorized senders."
        }
    }
}
