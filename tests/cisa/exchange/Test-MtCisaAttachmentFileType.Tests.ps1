Describe "CISA" -Tag "MS.EXO", "MS.EXO.9.2", "CISA.MS.EXO.9.2", "CISA", "Security" {
    It "CISA.MS.EXO.9.2: The attachment filter SHOULD attempt to determine the true file type and assess the file extension." {

        $result = Test-MtCisaAttachmentFileType

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}
