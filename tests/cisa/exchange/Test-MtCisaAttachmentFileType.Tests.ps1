Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.9.2", "CISA", "Security", "All" {
    It "MS.EXO.9.2: The attachment filter SHOULD attempt to determine the true file type and assess the file extension." {

        $result = Test-MtCisaAttachmentFileType

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}