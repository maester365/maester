Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.15.2", "CISA", "Security", "All" {
    It "MS.EXO.15.2: Direct download links SHOULD be scanned for malware." {

        $result = Test-MtCisaSafeLinkDownloadScan

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link scan enabled."
        }
    }
}