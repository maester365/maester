Describe "CISA" -Tag "MS.EXO", "MS.EXO.9.3", "CISA.MS.EXO.09.3", "CISA", "Security", "All" {
    It "CISA.MS.EXO.09.3: Disallowed file types SHALL be determined and enforced." {

        $result = Test-MtCisaAttachmentFileType

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}