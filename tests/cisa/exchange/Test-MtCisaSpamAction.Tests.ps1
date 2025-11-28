Describe "CISA" -Tag "MS.EXO", "MS.EXO.14.2", "CISA.MS.EXO.14.2", "CISA", "Security" {
    It "CISA.MS.EXO.14.2: Spam and high confidence spam SHALL be moved to either the junk email folder or the quarantine folder." {

        $result = Test-MtCisaSpamAction

        if ($null -ne $result) {
            $result | Should -Be $true -Because "spam filter enabled."
        }
    }
}
