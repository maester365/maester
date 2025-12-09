Describe "CISA" -Tag "MS.EXO", "MS.EXO.11.3", "CISA.MS.EXO.11.3", "CISA", "Security" {
    It "CISA.MS.EXO.11.3: The phishing protection solution SHOULD include an AI-based phishing detection tool comparable to EOP Mailbox Intelligence." {

        $result = Test-MtCisaMailboxIntelligence

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}
