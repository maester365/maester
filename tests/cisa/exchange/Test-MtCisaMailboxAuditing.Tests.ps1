Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.13.1", "CISA.MS.EXO.13.1", "CISA", "Security", "All" {
    It "CISA.MS.EXO.13.1: Mailbox auditing SHALL be enabled." {

        $cisaMailboxAuditing = Test-MtCisaMailboxAuditing

        if($null -ne $cisaMailboxAuditing) {
            $cisaMailboxAuditing | Should -Be $true -Because "mailbox auditing is enabled."
        }
    }
}