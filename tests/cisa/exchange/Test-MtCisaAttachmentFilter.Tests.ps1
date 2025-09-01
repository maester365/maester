Describe "CISA" -Tag "MS.EXO", "MS.EXO.9.1", "CISA.MS.EXO.9.1", "CISA", "Security" {
    It "CISA.MS.EXO.9.1: Emails SHALL be filtered by attachment file types." {

        $result = Test-MtCisaAttachmentFilter

        if ($null -ne $result) {
            $result | Should -Be $true -Because "policies exist."
        }
    }
}
