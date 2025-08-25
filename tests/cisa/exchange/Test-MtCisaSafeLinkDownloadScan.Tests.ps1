Describe "CISA" -Tag "MS.EXO", "MS.EXO.15.2", "CISA.MS.EXO.15.2", "CISA", "Security" {
    It "CISA.MS.EXO.15.2: Direct download links SHOULD be scanned for malware." {

        $result = Test-MtCisaSafeLinkDownloadScan

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link scan enabled."
        }
    }
}
