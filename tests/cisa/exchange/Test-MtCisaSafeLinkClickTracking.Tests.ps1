Describe "CISA" -Tag "MS.EXO", "MS.EXO.15.3", "CISA.MS.EXO.15.3", "CISA", "Security" {
    It "CISA.MS.EXO.15.3: User click tracking SHOULD be enabled." {

        $result = Test-MtCisaSafeLinkClickTracking

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link click tracking enabled."
        }
    }
}
