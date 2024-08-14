Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.15.3", "CISA", "Security", "All" {
    It "MS.EXO.15.3: User click tracking SHOULD be enabled." {

        $result = Test-MtCisaSafeLinkClickTracking

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe link click tracking enabled."
        }
    }
}